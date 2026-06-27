import 'dart:async';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:super_sync/src/adapter_registry.dart';
import 'package:super_sync/src/sync_conflict.dart';
import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_mutation.dart';
import 'package:super_sync/src/sync_operation.dart';
import 'package:super_sync/src/sync_record.dart';
import 'package:super_sync/src/sync_remote.dart';
import 'package:super_sync/src/sync_status.dart';
import 'package:synchronized/synchronized.dart';

/// Tuning knobs for the engine, chosen to stay bounded under load.
@immutable
class SyncConfig {
  /// Creates a config.
  const SyncConfig({
    this.pushBatchSize = 200,
    this.pullPageSize = 200,
    this.maxRetries = 5,
    this.retryBackoffBase = const Duration(seconds: 2),
    this.retryBackoffCap = const Duration(minutes: 5),
    this.cursorKey = '_global',
  });

  /// Maximum mutations per push request (the outbox is drained in batches).
  final int pushBatchSize;

  /// Page-size hint for each pull request (the server is drained page by page).
  final int pullPageSize;

  /// Attempts before a rejected mutation is dead-lettered.
  final int maxRetries;

  /// First retry delay; doubles each attempt up to [retryBackoffCap].
  final Duration retryBackoffBase;

  /// Upper bound on the retry delay.
  final Duration retryBackoffCap;

  /// Key under which the pull cursor is stored.
  final String cursorKey;
}

/// The convergence loop: drains the outbox to the server, then applies the
/// server's changes back into the store. Generic over every registered entity
/// type and safe to call concurrently — overlapping cycles are serialized.
@internal
class SyncEngine {
  /// Creates an engine over [store], [remote] and [registry].
  SyncEngine({
    required SyncLocalStore store,
    required SyncRemote remote,
    required AdapterRegistry registry,
    required ConflictStrategy conflictStrategy,
    SyncConfig config = const SyncConfig(),
  }) : _store = store,
       _remote = remote,
       _registry = registry,
       _strategy = conflictStrategy,
       _config = config;

  final SyncLocalStore _store;
  final SyncRemote _remote;
  final AdapterRegistry _registry;
  final ConflictStrategy _strategy;
  final SyncConfig _config;

  final Lock _lock = Lock();
  final StreamController<SyncStatus> _status =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();

  /// The live status stream (broadcast; replays the latest value on listen).
  Stream<SyncStatus> get status async* {
    yield _current;
    yield* _status.stream;
  }

  /// The latest status snapshot.
  SyncStatus get currentStatus => _current;

  void _emit(SyncStatus next) {
    _current = next;
    if (!_status.isClosed) _status.add(next);
  }

  /// Recomputes pending / dead-letter counts from the (possibly just-reopened)
  /// store and emits them, so the status is accurate before the first cycle.
  Future<void> refreshCounts() async {
    _emit(
      _current.copyWith(
        pendingChanges: await _store.pendingCount(
          maxRetries: _config.maxRetries,
        ),
        deadLettered: await _store.deadLetterCount(
          maxRetries: _config.maxRetries,
        ),
      ),
    );
  }

  /// Runs one full push+pull cycle. Concurrent calls coalesce behind a lock, so
  /// the storm of syncs triggered by rapid local writes collapses into back-to-
  /// back cycles rather than overlapping ones.
  Future<void> sync() => _lock.synchronized(_runCycle);

  Future<void> _runCycle() async {
    _emit(_current.copyWith(phase: SyncPhase.syncing, clearError: true));
    try {
      await _push();
      await _pull();
      _emit(
        SyncStatus(
          pendingChanges: await _store.pendingCount(
            maxRetries: _config.maxRetries,
          ),
          deadLettered: await _store.deadLetterCount(
            maxRetries: _config.maxRetries,
          ),
          lastSyncedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _emit(
        _current.copyWith(
          phase: SyncPhase.error,
          error: error,
          pendingChanges: await _store.pendingCount(
            maxRetries: _config.maxRetries,
          ),
          deadLettered: await _store.deadLetterCount(
            maxRetries: _config.maxRetries,
          ),
        ),
      );
    }
  }

  // --- Push ------------------------------------------------------------------

  Future<void> _push() async {
    SyncPageToken? after;
    while (true) {
      final batch = await _store.pendingMutations(
        limit: _config.pushBatchSize,
        after: after,
        maxRetries: _config.maxRetries,
      );
      if (batch.isEmpty) break;

      // A transport failure throws here; mutations stay pending (no retry bump)
      // and the next cycle picks them up.
      final response = await _remote.push(batch);
      final byId = {
        for (final r in response.results) r.mutationId: r,
      };

      final acknowledged = <String>[];
      final rescheduled = <SyncMutation>[];
      for (final mutation in batch) {
        final result = byId[mutation.id];
        if (result == null) {
          // Server omitted this one: leave it pending for the next cycle.
          continue;
        }
        switch (result.status) {
          case MutationStatus.applied:
            await _applyAck(mutation, result.serverVersion);
            acknowledged.add(mutation.id);
          case MutationStatus.conflict:
            final requeued = await _resolveConflict(mutation, result);
            acknowledged.add(mutation.id);
            if (requeued) {
              // The rebased change was re-enqueued as a fresh mutation; it will
              // be drained on a later page/cycle, not this one.
            }
          case MutationStatus.rejected:
            rescheduled.add(_withBackoff(mutation));
        }
      }
      await _store.removeMutations(acknowledged);
      await _store.rescheduleMutations(rescheduled);

      after = SyncPageToken(batch.last.id);
    }
  }

  Future<void> _applyAck(SyncMutation mutation, int? serverVersion) async {
    final record = await _store.readRecord(
      mutation.entityType,
      mutation.entityId,
    );
    if (record == null) return;
    await _store.putRecord(
      record.copyWith(
        serverVersion: serverVersion,
        localVersion: record.localVersion,
      ),
    );
  }

  /// Returns `true` if the local change was rebased and re-enqueued.
  Future<bool> _resolveConflict(
    SyncMutation mutation,
    MutationResult result,
  ) async {
    final entity = _registry.byName(mutation.entityType);
    final record = await _store.readRecord(
      mutation.entityType,
      mutation.entityId,
    );
    final remoteData = result.remoteData ?? const <String, Object?>{};
    final serverVersion = result.serverVersion;

    // No adapter or no local record: accept the server state.
    if (entity == null || record == null) {
      await _store.putRecord(
        SyncRecord(
          type: mutation.entityType,
          id: mutation.entityId,
          data: remoteData,
          localVersion: (record?.localVersion ?? 0) + 1,
          serverVersion: serverVersion,
          updatedAt: DateTime.now(),
        ),
      );
      return false;
    }

    Map<String, Object?> winner;
    if (entity.resolveData != null) {
      winner = await entity.resolveData!(record.data, remoteData);
    } else {
      winner = _strategy == ConflictStrategy.serverWins
          ? remoteData
          : record.data;
    }

    final serverWon =
        identical(winner, remoteData) ||
        (entity.resolveData == null &&
            _strategy == ConflictStrategy.serverWins);

    if (serverWon) {
      // Local change discarded; adopt the server's revision.
      await _store.putRecord(
        record.copyWith(
          data: winner,
          serverVersion: serverVersion,
          deleted: false,
        ),
      );
      return false;
    }

    // Keep the (possibly merged) local value: rebase onto the server revision
    // and re-enqueue so it pushes cleanly next time.
    final rebased = record.copyWith(
      data: winner,
      serverVersion: serverVersion,
      localVersion: record.localVersion + 1,
      updatedAt: DateTime.now(),
    );
    await _store.enqueue(
      SyncMutation(
        id: '${mutation.id}-r${record.localVersion + 1}',
        idempotencyKey:
            '${mutation.idempotencyKey}-r${record.localVersion + 1}',
        entityType: mutation.entityType,
        entityId: mutation.entityId,
        operation: SyncOperation.update,
        payload: winner,
        baseVersion: serverVersion,
        createdAt: DateTime.now(),
      ),
      rebased,
    );
    return true;
  }

  SyncMutation _withBackoff(SyncMutation mutation) {
    final attempt = mutation.retryCount + 1;
    final millis =
        (_config.retryBackoffBase.inMilliseconds *
                math.pow(2, mutation.retryCount))
            .toInt();
    final capped = math.min(millis, _config.retryBackoffCap.inMilliseconds);
    return mutation.copyWith(
      retryCount: attempt,
      nextRetryAt: DateTime.now().add(Duration(milliseconds: capped)),
    );
  }

  // --- Pull ------------------------------------------------------------------

  Future<void> _pull() async {
    // Entities with un-pushed local work must not be clobbered by the server;
    // skip them this pull (the next push reconciles them).
    final pending = await _store.pendingMutations(
      limit: 1 << 30,
      maxRetries: 1 << 30,
    );
    final locked = {
      for (final m in pending) '${m.entityType}/${m.entityId}',
    };

    var cursor = await _store.readCursor(_config.cursorKey);
    while (true) {
      final response = await _remote.pull(
        cursor: cursor,
        entityTypes: _registry.typeNames,
        limit: _config.pullPageSize,
      );
      for (final change in response.changes) {
        if (_registry.byName(change.entityType) == null) continue; // unknown
        final key = '${change.entityType}/${change.entityId}';
        if (locked.contains(key)) continue; // un-pushed local work wins
        await _applyRemote(change);
      }
      cursor = response.nextCursor;
      await _store.writeCursor(_config.cursorKey, cursor);
      if (!response.hasMore) break;
    }
  }

  Future<void> _applyRemote(RemoteChange change) async {
    final existing = await _store.readRecord(
      change.entityType,
      change.entityId,
    );
    final localVersion = existing?.localVersion ?? 1;
    if (change.operation == SyncOperation.delete) {
      await _store.putRecord(
        SyncRecord(
          type: change.entityType,
          id: change.entityId,
          data: existing?.data ?? const {},
          localVersion: localVersion,
          serverVersion: change.serverVersion,
          deleted: true,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    await _store.putRecord(
      SyncRecord(
        type: change.entityType,
        id: change.entityId,
        data: change.data ?? const {},
        localVersion: localVersion,
        serverVersion: change.serverVersion,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Hard-deletes acknowledged tombstones older than [olderThan].
  Future<int> purgeTombstones({required Duration olderThan}) =>
      _store.purgeTombstones(olderThan: DateTime.now().subtract(olderThan));

  /// Releases the status stream.
  Future<void> dispose() async {
    await _status.close();
  }
}
