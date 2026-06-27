import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_drift/src/database.dart';

/// A durable [SyncLocalStore] backed by SQLite via Drift.
///
/// Behaviourally identical to `InMemorySyncLocalStore` — same monotonic-apply
/// guard, outbox coalescing and keyset pagination — but rows survive restarts.
/// Reactivity rides Drift's own query streams (no manual notification gap), so
/// `watchAll` re-emits whenever a relevant row changes, including the optimistic
/// write inside the same transaction.
class DriftSyncLocalStore implements SyncLocalStore {
  /// Creates a store over [db].
  DriftSyncLocalStore(this.db);

  /// The underlying Drift database.
  final SuperSyncDatabase db;

  // --- Mapping ---------------------------------------------------------------

  SyncRecord _rec(SyncRecordRow r) => SyncRecord(
    type: r.type,
    id: r.id,
    data: jsonDecode(r.dataJson) as Map<String, Object?>,
    localVersion: r.localVersion,
    serverVersion: r.serverVersion,
    deleted: r.deleted,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );

  SyncRecordsCompanion _recCompanion(SyncRecord r) =>
      SyncRecordsCompanion.insert(
        type: r.type,
        id: r.id,
        dataJson: jsonEncode(r.data),
        localVersion: r.localVersion,
        serverVersion: Value(r.serverVersion),
        deleted: Value(r.deleted),
        updatedAt: r.updatedAt.millisecondsSinceEpoch,
      );

  SyncMutation _mut(SyncMutationRow m) => SyncMutation(
    id: m.id,
    idempotencyKey: m.idempotencyKey,
    entityType: m.entityType,
    entityId: m.entityId,
    operation: SyncOperation.values[m.operation],
    payload: jsonDecode(m.payloadJson) as Map<String, Object?>,
    baseVersion: m.baseVersion,
    retryCount: m.retryCount,
    nextRetryAt: m.nextRetryAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m.nextRetryAt!),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m.createdAt),
  );

  SyncMutationsCompanion _mutCompanion(SyncMutation m, {int? operation}) =>
      SyncMutationsCompanion.insert(
        id: m.id,
        idempotencyKey: m.idempotencyKey,
        entityType: m.entityType,
        entityId: m.entityId,
        operation: operation ?? m.operation.index,
        payloadJson: jsonEncode(m.payload),
        baseVersion: Value(m.baseVersion),
        retryCount: Value(m.retryCount),
        nextRetryAt: Value(m.nextRetryAt?.millisecondsSinceEpoch),
        createdAt: m.createdAt.millisecondsSinceEpoch,
      );

  bool _supersedes(SyncRecord incoming, SyncRecord? existing) {
    if (existing == null) return true;
    if (incoming.localVersion > existing.localVersion) return true;
    final inServer = incoming.serverVersion ?? -1;
    final exServer = existing.serverVersion ?? -1;
    return incoming.localVersion == existing.localVersion &&
        inServer > exServer;
  }

  // --- Records ---------------------------------------------------------------

  @override
  Future<void> initialize() async {
    await db.customSelect('SELECT 1').get();
  }

  @override
  Future<SyncRecord?> readRecord(String type, String id) async {
    final row = await (db.select(
      db.syncRecords,
    )..where((t) => t.type.equals(type) & t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _rec(row);
  }

  @override
  Future<List<SyncRecord>> readAll(
    String type, {
    bool includeDeleted = false,
  }) async {
    final rows =
        await (db.select(db.syncRecords)
              ..where((t) {
                var e = t.type.equals(type);
                if (!includeDeleted) e = e & t.deleted.equals(false);
                return e;
              })
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return rows.map(_rec).toList();
  }

  @override
  Future<SyncRecordPage> readPage(
    String type, {
    SyncPageToken? after,
    int limit = 50,
    bool includeDeleted = false,
  }) async {
    final rows =
        await (db.select(db.syncRecords)
              ..where((t) {
                var e = t.type.equals(type);
                if (!includeDeleted) e = e & t.deleted.equals(false);
                if (after != null) e = e & t.id.isBiggerThanValue(after.lastId);
                return e;
              })
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(limit + 1))
            .get();
    final hasMore = rows.length > limit;
    final page = (hasMore ? rows.sublist(0, limit) : rows).map(_rec).toList();
    return SyncRecordPage(
      records: page,
      nextPageToken: hasMore && page.isNotEmpty
          ? SyncPageToken(page.last.id)
          : null,
    );
  }

  @override
  Future<int> count(String type, {bool includeDeleted = false}) async {
    final exp = db.syncRecords.id.count();
    final row =
        await (db.selectOnly(db.syncRecords)
              ..addColumns([exp])
              ..where(() {
                var e = db.syncRecords.type.equals(type);
                if (!includeDeleted) {
                  e = e & db.syncRecords.deleted.equals(false);
                }
                return e;
              }()))
            .getSingle();
    return row.read(exp) ?? 0;
  }

  @override
  Future<void> putRecord(SyncRecord record) async {
    await db.transaction(() async {
      final existing = await readRecord(record.type, record.id);
      if (!_supersedes(record, existing)) return;
      await db
          .into(db.syncRecords)
          .insertOnConflictUpdate(_recCompanion(record));
    });
  }

  @override
  Future<void> removeRecord(String type, String id) async {
    await (db.delete(
      db.syncRecords,
    )..where((t) => t.type.equals(type) & t.id.equals(id))).go();
  }

  // --- Reactivity ------------------------------------------------------------

  @override
  Stream<List<SyncRecord>> watchAll(String type) {
    return (db.select(db.syncRecords)
          ..where((t) => t.type.equals(type) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch()
        .map((rows) => rows.map(_rec).toList());
  }

  @override
  Stream<SyncRecord?> watchRecord(String type, String id) {
    return (db.select(db.syncRecords)
          ..where((t) => t.type.equals(type) & t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => (row == null || row.deleted) ? null : _rec(row));
  }

  // --- Outbox ----------------------------------------------------------------

  @override
  Future<void> enqueue(SyncMutation mutation, SyncRecord record) async {
    await db.transaction(() async {
      final existing =
          await (db.select(db.syncMutations)..where(
                (t) =>
                    t.entityType.equals(mutation.entityType) &
                    t.entityId.equals(mutation.entityId),
              ))
              .getSingleOrNull();

      var operation = mutation.operation.index;
      if (existing != null) {
        await (db.delete(
          db.syncMutations,
        )..where((t) => t.id.equals(existing.id))).go();
        final existingOp = SyncOperation.values[existing.operation];
        // Create-then-delete of a never-synced entity is a net no-op.
        if (existingOp == SyncOperation.create &&
            mutation.operation == SyncOperation.delete) {
          await removeRecord(record.type, record.id);
          return;
        }
        if (existingOp == SyncOperation.create) {
          operation = SyncOperation.create.index;
        }
      }

      await db
          .into(db.syncMutations)
          .insert(_mutCompanion(mutation, operation: operation));

      final current = await readRecord(record.type, record.id);
      if (_supersedes(record, current)) {
        await db
            .into(db.syncRecords)
            .insertOnConflictUpdate(_recCompanion(record));
      }
    });
  }

  @override
  Future<List<SyncMutation>> pendingMutations({
    int limit = 500,
    SyncPageToken? after,
    int maxRetries = 5,
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows =
        await (db.select(db.syncMutations)
              ..where((t) {
                var e =
                    t.retryCount.isSmallerThanValue(maxRetries) &
                    (t.nextRetryAt.isNull() |
                        t.nextRetryAt.isSmallerOrEqualValue(ts));
                if (after != null) e = e & t.id.isBiggerThanValue(after.lastId);
                return e;
              })
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(limit))
            .get();
    return rows.map(_mut).toList();
  }

  @override
  Future<void> removeMutations(Iterable<String> mutationIds) async {
    final ids = mutationIds.toList();
    if (ids.isEmpty) return;
    await (db.delete(db.syncMutations)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<void> rescheduleMutations(Iterable<SyncMutation> mutations) async {
    await db.transaction(() async {
      for (final m in mutations) {
        await (db.update(
          db.syncMutations,
        )..where((t) => t.id.equals(m.id))).write(
          SyncMutationsCompanion(
            retryCount: Value(m.retryCount),
            nextRetryAt: Value(m.nextRetryAt?.millisecondsSinceEpoch),
          ),
        );
      }
    });
  }

  @override
  Future<int> pendingCount({int maxRetries = 5}) async {
    final exp = db.syncMutations.id.count();
    final row =
        await (db.selectOnly(db.syncMutations)
              ..addColumns([exp])
              ..where(
                db.syncMutations.retryCount.isSmallerThanValue(maxRetries),
              ))
            .getSingle();
    return row.read(exp) ?? 0;
  }

  @override
  Future<int> deadLetterCount({int maxRetries = 5}) async {
    final exp = db.syncMutations.id.count();
    final row =
        await (db.selectOnly(db.syncMutations)
              ..addColumns([exp])
              ..where(
                db.syncMutations.retryCount.isBiggerOrEqualValue(maxRetries),
              ))
            .getSingle();
    return row.read(exp) ?? 0;
  }

  // --- Cursors ---------------------------------------------------------------

  @override
  Future<String?> readCursor(String key) async {
    final row = await (db.select(
      db.syncCursors,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> writeCursor(String key, String? cursor) async {
    await db
        .into(db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(key: key, value: Value(cursor)),
        );
  }

  // --- Maintenance -----------------------------------------------------------

  @override
  Future<int> purgeTombstones({required DateTime olderThan}) async {
    return db.transaction(() async {
      final cutoff = olderThan.millisecondsSinceEpoch;
      final candidates =
          await (db.select(db.syncRecords)..where(
                (t) =>
                    t.deleted.equals(true) &
                    t.updatedAt.isSmallerThanValue(cutoff),
              ))
              .get();
      final referenced = (await db.select(db.syncMutations).get())
          .map((m) => '${m.entityType}/${m.entityId}')
          .toSet();
      var purged = 0;
      for (final r in candidates) {
        if (referenced.contains('${r.type}/${r.id}')) continue;
        await removeRecord(r.type, r.id);
        purged++;
      }
      return purged;
    });
  }

  @override
  Future<void> close() => db.close();
}
