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
class DriftSyncLocalStore implements SyncLocalStore, SyncQueryableStore {
  /// Creates a store over [db].
  DriftSyncLocalStore(this.db);

  /// The underlying Drift database.
  final SuperSyncDatabase db;

  /// Configured projections, keyed by entity type.
  final Map<String, SyncProjection> _projections = {};

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
      await _project(record);
    });
  }

  @override
  Future<void> removeRecord(String type, String id) async {
    await (db.delete(
      db.syncRecords,
    )..where((t) => t.type.equals(type) & t.id.equals(id))).go();
    await _unproject(type, id);
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
        await _project(record);
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

  // --- Typed projections -----------------------------------------------------

  String _tableName(String type) => 'proj_${_sanitize(type)}';
  String _col(String name) => _sanitize(name);
  String _sanitize(String s) => s.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');

  String _sqlType(SyncFieldType t) => switch (t) {
    SyncFieldType.text => 'TEXT',
    SyncFieldType.integer => 'INTEGER',
    // Booleans are stored as INTEGER 0/1.
    SyncFieldType.boolean => 'INTEGER',
    SyncFieldType.real => 'REAL',
  };

  Object? _extract(SyncField f, Object? raw) {
    if (raw == null) return null;
    return switch (f.type) {
      SyncFieldType.text => raw.toString(),
      SyncFieldType.integer => (raw as num).toInt(),
      SyncFieldType.real => (raw as num).toDouble(),
      SyncFieldType.boolean => (raw == true || raw == 1) ? 1 : 0,
    };
  }

  @override
  Future<void> configureProjections(List<SyncProjection> projections) async {
    for (final proj in projections) {
      _projections[proj.type] = proj;
      await _migrateTable(proj);
    }
  }

  /// Creates or migrates [proj]'s typed table. Additive changes (new columns)
  /// are applied in place; any incompatible change rebuilds the table from the
  /// JSON blob — so the caller never writes a migration.
  Future<void> _migrateTable(SyncProjection proj) async {
    final table = _tableName(proj.type);
    final info = await db.customSelect("PRAGMA table_info('$table')").get();
    final existing = <String, String>{
      for (final row in info)
        (row.data['name'] as String): (row.data['type'] as String)
            .toUpperCase(),
    };

    final desired = <String, String>{'id': 'TEXT'};
    for (final f in proj.fields) {
      desired[_col(f.name)] = _sqlType(f.type);
    }

    if (existing.isEmpty) {
      await _createTable(proj);
      await _backfill(proj);
      return;
    }

    // Compatible iff every existing column survives unchanged in the new shape.
    final compatible = existing.entries.every(
      (e) => desired[e.key] == e.value,
    );
    if (!compatible) {
      await db.customStatement('DROP TABLE IF EXISTS $table');
      await _createTable(proj);
      await _backfill(proj);
      return;
    }

    // Additive: add the new columns and backfill just those.
    final added = desired.keys.where((c) => !existing.containsKey(c)).toList();
    for (final c in added) {
      await db.customStatement(
        'ALTER TABLE $table ADD COLUMN $c ${desired[c]}',
      );
    }
    await _createIndexes(proj);
    if (added.isNotEmpty) await _backfill(proj);
  }

  Future<void> _createTable(SyncProjection proj) async {
    final table = _tableName(proj.type);
    final cols = <String>[
      'id TEXT PRIMARY KEY',
      for (final f in proj.fields) '${_col(f.name)} ${_sqlType(f.type)}',
    ];
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS $table (${cols.join(', ')})',
    );
    await _createIndexes(proj);
  }

  Future<void> _createIndexes(SyncProjection proj) async {
    final table = _tableName(proj.type);
    for (final f in proj.fields) {
      if (!f.indexed) continue;
      final col = _col(f.name);
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${table}_$col ON $table($col)',
      );
    }
  }

  /// Rebuilds [proj]'s table contents from the blob — the source of truth.
  Future<void> _backfill(SyncProjection proj) async {
    final rows =
        await (db.select(db.syncRecords)..where(
              (t) => t.type.equals(proj.type) & t.deleted.equals(false),
            ))
            .get();
    for (final row in rows) {
      await _project(_rec(row));
    }
  }

  /// Writes [record]'s projected columns (or removes the row if it's a
  /// tombstone). No-op when the type has no configured projection.
  Future<void> _project(SyncRecord record) async {
    final proj = _projections[record.type];
    if (proj == null) return;
    final table = _tableName(record.type);
    if (record.deleted) {
      await db.customStatement('DELETE FROM $table WHERE id = ?', [record.id]);
      return;
    }
    final cols = <String>['id', for (final f in proj.fields) _col(f.name)];
    final values = <Object?>[
      record.id,
      for (final f in proj.fields) _extract(f, record.data[f.jsonKey]),
    ];
    final placeholders = List.filled(cols.length, '?').join(', ');
    await db.customStatement(
      'INSERT OR REPLACE INTO $table (${cols.join(', ')}) VALUES ($placeholders)',
      values,
    );
  }

  Future<void> _unproject(String type, String id) async {
    if (!_projections.containsKey(type)) return;
    await db.customStatement(
      'DELETE FROM ${_tableName(type)} WHERE id = ?',
      [id],
    );
  }

  @override
  Future<List<SyncRecord>> queryProjection(
    String type, {
    String? where,
    List<Object?> whereArgs = const [],
    String? orderBy,
    int? limit,
  }) async {
    if (!_projections.containsKey(type)) {
      throw StateError(
        'No projection configured for "$type". Declare fields via '
        'collection(fields: ...) or register(fields: ...).',
      );
    }
    final table = _tableName(type);
    final sql = StringBuffer(
      'SELECT r.type AS type, r.id AS id, r.data_json AS data_json, '
      'r.local_version AS local_version, r.server_version AS server_version, '
      'r.deleted AS deleted, r.updated_at AS updated_at '
      'FROM $table p JOIN sync_records r ON r.id = p.id AND r.type = ? '
      'WHERE r.deleted = 0',
    );
    final vars = <Variable<Object>>[Variable.withString(type)];
    if (where != null && where.isNotEmpty) {
      sql.write(' AND ($where)');
      for (final a in whereArgs) {
        vars.add(_variable(a));
      }
    }
    if (orderBy != null && orderBy.isNotEmpty) sql.write(' ORDER BY $orderBy');
    if (limit != null) sql.write(' LIMIT $limit');

    final rows = await db.customSelect(sql.toString(), variables: vars).get();
    return rows.map((row) {
      final data = row.read<String>('data_json');
      return SyncRecord(
        type: row.read<String>('type'),
        id: row.read<String>('id'),
        data: jsonDecode(data) as Map<String, Object?>,
        localVersion: row.read<int>('local_version'),
        serverVersion: row.readNullable<int>('server_version'),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('updated_at'),
        ),
      );
    }).toList();
  }

  Variable<Object> _variable(Object? value) => switch (value) {
    null => const Variable<String>(null),
    final int v => Variable.withInt(v),
    final double v => Variable.withReal(v),
    final bool v => Variable.withInt(v ? 1 : 0),
    final String v => Variable.withString(v),
    _ => Variable.withString(value.toString()),
  };

  @override
  Future<void> close() => db.close();
}
