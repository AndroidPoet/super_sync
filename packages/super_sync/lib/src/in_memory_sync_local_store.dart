import 'dart:async';

import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_mutation.dart';
import 'package:super_sync/src/sync_operation.dart';
import 'package:super_sync/src/sync_record.dart';

/// A fully-featured, dependency-free [SyncLocalStore] backed by maps.
///
/// Ships in the box so the engine round-trips end to end with no database, and
/// is the executable specification every durable store (e.g. Drift) must match:
/// monotonic-apply guard, per-entity outbox coalescing, keyset pagination and
/// broadcast reactivity. Suitable for tests, prototypes and small datasets;
/// swap in `super_sync_drift` for persistence at scale.
class InMemorySyncLocalStore implements SyncLocalStore {
  // type -> (id -> record)
  final Map<String, Map<String, SyncRecord>> _records = {};
  final List<SyncMutation> _outbox = [];
  final Map<String, String?> _cursors = {};
  final Map<String, StreamController<void>> _ticks = {};

  StreamController<void> _tick(String type) =>
      _ticks.putIfAbsent(type, StreamController<void>.broadcast);

  void _notify(String type) {
    final c = _ticks[type];
    if (c != null && !c.isClosed) c.add(null);
  }

  List<SyncRecord> _live(String type, {bool includeDeleted = false}) {
    final byId = _records[type];
    if (byId == null) return const [];
    final out = byId.values.where((r) => includeDeleted || !r.deleted).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  /// Whether [incoming] should replace the stored record (monotonic guard).
  bool _supersedes(SyncRecord incoming, SyncRecord? existing) {
    if (existing == null) return true;
    if (incoming.localVersion > existing.localVersion) return true;
    final inServer = incoming.serverVersion ?? -1;
    final exServer = existing.serverVersion ?? -1;
    return incoming.localVersion == existing.localVersion &&
        inServer > exServer;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncRecord?> readRecord(String type, String id) async =>
      _records[type]?[id];

  @override
  Future<List<SyncRecord>> readAll(
    String type, {
    bool includeDeleted = false,
  }) async => _live(type, includeDeleted: includeDeleted);

  @override
  Future<SyncRecordPage> readPage(
    String type, {
    SyncPageToken? after,
    int limit = 50,
    bool includeDeleted = false,
  }) async {
    var rows = _live(type, includeDeleted: includeDeleted);
    if (after != null) {
      rows = rows.where((r) => r.id.compareTo(after.lastId) > 0).toList();
    }
    final page = rows.take(limit).toList();
    final hasMore = rows.length > limit;
    return SyncRecordPage(
      records: page,
      nextPageToken: hasMore && page.isNotEmpty
          ? SyncPageToken(page.last.id)
          : null,
    );
  }

  @override
  Future<int> count(String type, {bool includeDeleted = false}) async =>
      _live(type, includeDeleted: includeDeleted).length;

  @override
  Future<void> putRecord(SyncRecord record) async {
    final byId = _records.putIfAbsent(record.type, () => {});
    if (!_supersedes(record, byId[record.id])) return;
    byId[record.id] = record;
    _notify(record.type);
  }

  @override
  Future<void> removeRecord(String type, String id) async {
    final removed = _records[type]?.remove(id);
    if (removed != null) _notify(type);
  }

  @override
  Stream<List<SyncRecord>> watchAll(String type) {
    // Subscribe to the tick stream *synchronously inside onListen* and emit the
    // current snapshot in the same turn, so no change slips through between the
    // initial read and the subscription (the async* form had that gap).
    late final StreamController<List<SyncRecord>> ctrl;
    StreamSubscription<void>? sub;
    ctrl = StreamController<List<SyncRecord>>(
      onListen: () {
        sub = _tick(type).stream.listen((_) => ctrl.add(_live(type)));
        ctrl.add(_live(type));
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  @override
  Stream<SyncRecord?> watchRecord(String type, String id) {
    SyncRecord? current() {
      final r = _records[type]?[id];
      return (r == null || r.deleted) ? null : r;
    }

    late final StreamController<SyncRecord?> ctrl;
    StreamSubscription<void>? sub;
    ctrl = StreamController<SyncRecord?>(
      onListen: () {
        sub = _tick(type).stream.listen((_) => ctrl.add(current()));
        ctrl.add(current());
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  @override
  Future<void> enqueue(SyncMutation mutation, SyncRecord record) async {
    // Coalesce: a still-pending mutation for the same entity is folded into the
    // new one so a burst of edits costs one push, not one per keystroke.
    final existingIndex = _outbox.indexWhere(
      (m) =>
          m.entityType == mutation.entityType &&
          m.entityId == mutation.entityId,
    );
    final byId = _records.putIfAbsent(record.type, () => {});

    if (existingIndex >= 0) {
      final existing = _outbox[existingIndex];
      _outbox.removeAt(existingIndex);
      // Create-then-delete of a never-synced entity is a net no-op.
      if (existing.operation == SyncOperation.create &&
          mutation.operation == SyncOperation.delete) {
        byId.remove(record.id);
        _notify(record.type);
        return;
      }
      // Preserve create semantics when later edited before first sync.
      final op = existing.operation == SyncOperation.create
          ? SyncOperation.create
          : mutation.operation;
      _outbox.add(mutation.copyWith()._withOperation(op));
    } else {
      _outbox.add(mutation);
    }

    if (_supersedes(record, byId[record.id])) {
      byId[record.id] = record;
    }
    _notify(record.type);
  }

  @override
  Future<List<SyncMutation>> pendingMutations({
    int limit = 500,
    SyncPageToken? after,
    int maxRetries = 5,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final eligible =
        _outbox
            .where(
              (m) =>
                  m.retryCount < maxRetries &&
                  (m.nextRetryAt == null || !m.nextRetryAt!.isAfter(ts)),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final from = after == null
        ? eligible
        : eligible.where((m) => m.id.compareTo(after.lastId) > 0).toList();
    return from.take(limit).toList();
  }

  @override
  Future<void> removeMutations(Iterable<String> mutationIds) async {
    final ids = mutationIds.toSet();
    _outbox.removeWhere((m) => ids.contains(m.id));
  }

  @override
  Future<void> rescheduleMutations(Iterable<SyncMutation> mutations) async {
    for (final m in mutations) {
      final i = _outbox.indexWhere((e) => e.id == m.id);
      if (i >= 0) _outbox[i] = m;
    }
  }

  @override
  Future<int> pendingCount({int maxRetries = 5}) async =>
      _outbox.where((m) => m.retryCount < maxRetries).length;

  @override
  Future<int> deadLetterCount({int maxRetries = 5}) async =>
      _outbox.where((m) => m.retryCount >= maxRetries).length;

  @override
  Future<String?> readCursor(String key) async => _cursors[key];

  @override
  Future<void> writeCursor(String key, String? cursor) async =>
      _cursors[key] = cursor;

  @override
  Future<int> purgeTombstones({required DateTime olderThan}) async {
    final referenced = _outbox
        .map((m) => '${m.entityType}/${m.entityId}')
        .toSet();
    var purged = 0;
    for (final entry in _records.entries) {
      final type = entry.key;
      final remove = entry.value.values
          .where(
            (r) =>
                r.deleted &&
                r.updatedAt.isBefore(olderThan) &&
                !referenced.contains('$type/${r.id}'),
          )
          .map((r) => r.id)
          .toList();
      for (final id in remove) {
        entry.value.remove(id);
        purged++;
      }
      if (remove.isNotEmpty) _notify(type);
    }
    return purged;
  }

  @override
  Future<void> close() async {
    for (final c in _ticks.values) {
      await c.close();
    }
    _ticks.clear();
  }
}

extension on SyncMutation {
  SyncMutation _withOperation(SyncOperation op) => SyncMutation(
    id: id,
    idempotencyKey: idempotencyKey,
    entityType: entityType,
    entityId: entityId,
    operation: op,
    payload: payload,
    baseVersion: baseVersion,
    retryCount: retryCount,
    nextRetryAt: nextRetryAt,
    createdAt: createdAt,
  );
}
