import 'package:drift/drift.dart';

part 'database.g.dart';

/// The generic record envelope, one row per (type, id).
@DataClassName('SyncRecordRow')
@TableIndex(name: 'idx_records_type', columns: {#type})
class SyncRecords extends Table {
  TextColumn get type => text()();
  TextColumn get id => text()();
  TextColumn get dataJson => text()();
  IntColumn get localVersion => integer()();
  IntColumn get serverVersion => integer().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()(); // epoch millis

  @override
  Set<Column<Object>> get primaryKey => {type, id};
}

/// The outbox: one row per queued local change.
@DataClassName('SyncMutationRow')
@TableIndex(name: 'idx_mutations_entity', columns: {#entityType, #entityId})
class SyncMutations extends Table {
  TextColumn get id => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get operation => integer()(); // SyncOperation.index
  TextColumn get payloadJson => text()();
  IntColumn get baseVersion => integer().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().nullable()(); // epoch millis
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pull cursors, keyed by scope.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The Drift database backing [DriftSyncLocalStore].
@DriftDatabase(tables: [SyncRecords, SyncMutations, SyncCursors])
class SuperSyncDatabase extends _$SuperSyncDatabase {
  /// Opens the database over the given query executor.
  SuperSyncDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
