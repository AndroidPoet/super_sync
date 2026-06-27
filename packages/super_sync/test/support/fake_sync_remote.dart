import 'package:super_sync/super_sync.dart';

class _Entity {
  // Private test fixture; positional args keep the seed/apply code terse.
  // ignore: avoid_positional_boolean_parameters
  _Entity(this.data, this.version, this.deleted, this.seq);
  Map<String, Object?> data;
  int version;
  bool deleted;
  int seq;
}

/// An in-memory server implementing the generic Super Sync protocol: per-entity
/// versioning, optimistic-concurrency conflict detection, a monotonic change
/// log and keyset-paged pull. Faithful enough to exercise the engine end to end.
class FakeSyncRemote implements SyncRemote {
  final Map<String, Map<String, _Entity>> _db = {};
  int _seq = 0;

  /// Force every [push] to throw, simulating an offline transport.
  bool offline = false;

  /// Reject (not conflict) any mutation whose type is in this set.
  final Set<String> rejectTypes = {};

  int pushCalls = 0;
  int pullCalls = 0;

  /// Simulate a write from another client.
  void seed(String type, String id, Map<String, Object?> data, int version) {
    _seq++;
    _db.putIfAbsent(type, () => {})[id] = _Entity(data, version, false, _seq);
  }

  Map<String, Object?>? dataOf(String type, String id) {
    final e = _db[type]?[id];
    return (e == null || e.deleted) ? null : e.data;
  }

  @override
  Future<PushResponse> push(List<SyncMutation> mutations) async {
    pushCalls++;
    if (offline) throw StateError('offline');
    final results = <MutationResult>[];
    for (final m in mutations) {
      if (rejectTypes.contains(m.entityType)) {
        results.add(
          MutationResult(
            mutationId: m.id,
            status: MutationStatus.rejected,
            error: 'rejected by test',
          ),
        );
        continue;
      }
      final byId = _db.putIfAbsent(m.entityType, () => {});
      final cur = byId[m.entityId];
      final curVersion = cur?.version;
      final conflict = m.operation == SyncOperation.create
          ? (cur != null && !cur.deleted)
          : (cur != null && m.baseVersion != curVersion);
      if (conflict) {
        results.add(
          MutationResult(
            mutationId: m.id,
            status: MutationStatus.conflict,
            serverVersion: cur.version,
            remoteData: cur.deleted ? null : cur.data,
          ),
        );
        continue;
      }
      _seq++;
      final newVersion = (curVersion ?? 0) + 1;
      byId[m.entityId] = _Entity(
        m.operation == SyncOperation.delete ? (cur?.data ?? {}) : m.payload,
        newVersion,
        m.operation == SyncOperation.delete,
        _seq,
      );
      results.add(
        MutationResult(
          mutationId: m.id,
          status: MutationStatus.applied,
          serverVersion: newVersion,
        ),
      );
    }
    return PushResponse(results);
  }

  @override
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  }) async {
    pullCalls++;
    final from = cursor == null ? 0 : int.parse(cursor);
    final rows = <({int seq, RemoteChange change})>[];
    for (final typeEntry in _db.entries) {
      if (entityTypes != null && !entityTypes.contains(typeEntry.key)) continue;
      for (final e in typeEntry.value.entries) {
        if (e.value.seq <= from) continue;
        rows.add((
          seq: e.value.seq,
          change: RemoteChange(
            entityType: typeEntry.key,
            entityId: e.key,
            operation: e.value.deleted
                ? SyncOperation.delete
                : SyncOperation.update,
            serverVersion: e.value.version,
            data: e.value.deleted ? null : e.value.data,
          ),
        ));
      }
    }
    rows.sort((a, b) => a.seq.compareTo(b.seq));
    final pageSize = limit ?? rows.length;
    final page = rows.take(pageSize).toList();
    final hasMore = rows.length > pageSize;
    return PullResponse(
      changes: page.map((r) => r.change).toList(),
      nextCursor: page.isEmpty ? cursor : page.last.seq.toString(),
      hasMore: hasMore,
    );
  }
}
