import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:super_sync/super_sync.dart';

/// A durable [SyncLocalStore] backed by SQLite via sqflite.
///
/// Behaviourally identical to the in-memory and Drift stores — same
/// monotonic-apply guard, outbox coalescing and keyset pagination. Because
/// sqflite has **no reactive query streams**, this store implements
/// `watchAll` / `watchRecord` with a manual per-type change notifier: every
/// write that touches a type pokes a broadcast tick, and the stream re-queries.
///
/// Construct it over any sqflite [Database] (from `package:sqflite` on a device,
/// or `sqflite_common_ffi` on desktop / tests) and call [initialize] once.
class SqfliteSyncLocalStore implements SyncLocalStore {
  /// Creates a store over an open sqflite [db].
  SqfliteSyncLocalStore(this.db);

  /// The underlying sqflite database.
  final Database db;

  final Map<String, StreamController<void>> _ticks = {};

  StreamController<void> _tick(String type) =>
      _ticks.putIfAbsent(type, StreamController<void>.broadcast);

  void _notify(String type) {
    final c = _ticks[type];
    if (c != null && !c.isClosed) c.add(null);
  }

  // --- Mapping ---------------------------------------------------------------

  SyncRecord _rec(Map<String, Object?> r) => SyncRecord(
    type: r['type']! as String,
    id: r['id']! as String,
    data: jsonDecode(r['data_json']! as String) as Map<String, Object?>,
    localVersion: r['local_version']! as int,
    serverVersion: r['server_version'] as int?,
    deleted: (r['deleted']! as int) == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
  );

  Map<String, Object?> _recRow(SyncRecord r) => {
    'type': r.type,
    'id': r.id,
    'data_json': jsonEncode(r.data),
    'local_version': r.localVersion,
    'server_version': r.serverVersion,
    'deleted': r.deleted ? 1 : 0,
    'updated_at': r.updatedAt.millisecondsSinceEpoch,
  };

  SyncMutation _mut(Map<String, Object?> m) => SyncMutation(
    id: m['id']! as String,
    idempotencyKey: m['idempotency_key']! as String,
    entityType: m['entity_type']! as String,
    entityId: m['entity_id']! as String,
    operation: SyncOperation.values[m['operation']! as int],
    payload: jsonDecode(m['payload_json']! as String) as Map<String, Object?>,
    baseVersion: m['base_version'] as int?,
    retryCount: m['retry_count']! as int,
    nextRetryAt: m['next_retry_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['next_retry_at']! as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
  );

  Map<String, Object?> _mutRow(SyncMutation m, {int? operation}) => {
    'id': m.id,
    'idempotency_key': m.idempotencyKey,
    'entity_type': m.entityType,
    'entity_id': m.entityId,
    'operation': operation ?? m.operation.index,
    'payload_json': jsonEncode(m.payload),
    'base_version': m.baseVersion,
    'retry_count': m.retryCount,
    'next_retry_at': m.nextRetryAt?.millisecondsSinceEpoch,
    'created_at': m.createdAt.millisecondsSinceEpoch,
  };

  bool _supersedes(SyncRecord incoming, SyncRecord? existing) {
    if (existing == null) return true;
    if (incoming.localVersion > existing.localVersion) return true;
    final inServer = incoming.serverVersion ?? -1;
    final exServer = existing.serverVersion ?? -1;
    return incoming.localVersion == existing.localVersion &&
        inServer > exServer;
  }

  Future<SyncRecord?> _readRecord(
    DatabaseExecutor x,
    String type,
    String id,
  ) async {
    final rows = await x.query(
      'sync_records',
      where: 'type = ? AND id = ?',
      whereArgs: [type, id],
      limit: 1,
    );
    return rows.isEmpty ? null : _rec(rows.first);
  }

  // --- Lifecycle -------------------------------------------------------------

  @override
  Future<void> initialize() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_records(
        type TEXT NOT NULL,
        id TEXT NOT NULL,
        data_json TEXT NOT NULL,
        local_version INTEGER NOT NULL,
        server_version INTEGER,
        deleted INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(type, id)
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_records_type ON sync_records(type)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_mutations(
        id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation INTEGER NOT NULL,
        payload_json TEXT NOT NULL,
        base_version INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        created_at INTEGER NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mut_entity '
      'ON sync_mutations(entity_type, entity_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_cursors(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
  }

  // --- Records ---------------------------------------------------------------

  @override
  Future<SyncRecord?> readRecord(String type, String id) =>
      _readRecord(db, type, id);

  @override
  Future<List<SyncRecord>> readAll(
    String type, {
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      'sync_records',
      where: includeDeleted ? 'type = ?' : 'type = ? AND deleted = 0',
      whereArgs: [type],
      orderBy: 'id ASC',
    );
    return rows.map(_rec).toList();
  }

  @override
  Future<SyncRecordPage> readPage(
    String type, {
    SyncPageToken? after,
    int limit = 50,
    bool includeDeleted = false,
  }) async {
    final where = StringBuffer('type = ?');
    final args = <Object?>[type];
    if (!includeDeleted) where.write(' AND deleted = 0');
    if (after != null) {
      where.write(' AND id > ?');
      args.add(after.lastId);
    }
    final rows = await db.query(
      'sync_records',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: limit + 1,
    );
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
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_records WHERE type = ?'
      '${includeDeleted ? '' : ' AND deleted = 0'}',
      [type],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> putRecord(SyncRecord record) async {
    await db.transaction((txn) async {
      final existing = await _readRecord(txn, record.type, record.id);
      if (!_supersedes(record, existing)) return;
      await txn.insert(
        'sync_records',
        _recRow(record),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _notify(record.type);
  }

  @override
  Future<void> removeRecord(String type, String id) async {
    await db.delete(
      'sync_records',
      where: 'type = ? AND id = ?',
      whereArgs: [type, id],
    );
    _notify(type);
  }

  // --- Reactivity (manual: sqflite has no query streams) ---------------------

  @override
  Stream<List<SyncRecord>> watchAll(String type) {
    late final StreamController<List<SyncRecord>> ctrl;
    StreamSubscription<void>? sub;
    Future<void> emit() async => ctrl.add(await readAll(type));
    ctrl = StreamController<List<SyncRecord>>(
      onListen: () {
        sub = _tick(type).stream.listen((_) => unawaited(emit()));
        unawaited(emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  @override
  Stream<SyncRecord?> watchRecord(String type, String id) {
    late final StreamController<SyncRecord?> ctrl;
    StreamSubscription<void>? sub;
    Future<void> emit() async {
      final r = await readRecord(type, id);
      ctrl.add((r == null || r.deleted) ? null : r);
    }

    ctrl = StreamController<SyncRecord?>(
      onListen: () {
        sub = _tick(type).stream.listen((_) => unawaited(emit()));
        unawaited(emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  // --- Outbox ----------------------------------------------------------------

  @override
  Future<void> enqueue(SyncMutation mutation, SyncRecord record) async {
    await db.transaction((txn) async {
      final existing = await txn.query(
        'sync_mutations',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [mutation.entityType, mutation.entityId],
        limit: 1,
      );

      var operation = mutation.operation.index;
      if (existing.isNotEmpty) {
        final existingOp =
            SyncOperation.values[existing.first['operation']! as int];
        await txn.delete(
          'sync_mutations',
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        // Create-then-delete of a never-synced entity is a net no-op.
        if (existingOp == SyncOperation.create &&
            mutation.operation == SyncOperation.delete) {
          await txn.delete(
            'sync_records',
            where: 'type = ? AND id = ?',
            whereArgs: [record.type, record.id],
          );
          return;
        }
        if (existingOp == SyncOperation.create) {
          operation = SyncOperation.create.index;
        }
      }

      await txn.insert(
        'sync_mutations',
        _mutRow(mutation, operation: operation),
      );

      final current = await _readRecord(txn, record.type, record.id);
      if (_supersedes(record, current)) {
        await txn.insert(
          'sync_records',
          _recRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    _notify(record.type);
  }

  @override
  Future<List<SyncMutation>> pendingMutations({
    int limit = 500,
    SyncPageToken? after,
    int maxRetries = 5,
    DateTime? now,
  }) async {
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final where = StringBuffer(
      'retry_count < ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
    );
    final args = <Object?>[maxRetries, ts];
    if (after != null) {
      where.write(' AND id > ?');
      args.add(after.lastId);
    }
    final rows = await db.query(
      'sync_mutations',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(_mut).toList();
  }

  @override
  Future<void> removeMutations(Iterable<String> mutationIds) async {
    final ids = mutationIds.toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      'sync_mutations',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  @override
  Future<void> rescheduleMutations(Iterable<SyncMutation> mutations) async {
    await db.transaction((txn) async {
      for (final m in mutations) {
        await txn.update(
          'sync_mutations',
          {
            'retry_count': m.retryCount,
            'next_retry_at': m.nextRetryAt?.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [m.id],
        );
      }
    });
  }

  @override
  Future<int> pendingCount({int maxRetries = 5}) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_mutations WHERE retry_count < ?',
      [maxRetries],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> deadLetterCount({int maxRetries = 5}) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_mutations WHERE retry_count >= ?',
      [maxRetries],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // --- Cursors ---------------------------------------------------------------

  @override
  Future<String?> readCursor(String key) async {
    final rows = await db.query(
      'sync_cursors',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> writeCursor(String key, String? cursor) async {
    await db.insert(
      'sync_cursors',
      {'key': key, 'value': cursor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Maintenance -----------------------------------------------------------

  @override
  Future<int> purgeTombstones({required DateTime olderThan}) async {
    final cutoff = olderThan.millisecondsSinceEpoch;
    final purged = await db.rawDelete(
      'DELETE FROM sync_records WHERE deleted = 1 AND updated_at < ? '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM sync_mutations m '
      '  WHERE m.entity_type = sync_records.type '
      '  AND m.entity_id = sync_records.id '
      ')',
      [cutoff],
    );
    if (purged > 0) {
      for (final c in _ticks.values) {
        if (!c.isClosed) c.add(null);
      }
    }
    return purged;
  }

  @override
  Future<void> close() async {
    for (final c in _ticks.values) {
      await c.close();
    }
    _ticks.clear();
    await db.close();
  }
}
