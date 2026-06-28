import 'package:super_sync/src/sync_projection.dart';
import 'package:super_sync/src/sync_record.dart';

/// An optional capability a [SyncLocalStore] may also implement to support
/// typed, indexed queries over projected columns.
///
/// The JSON blob remains the source of truth; a queryable store additionally
/// maintains a derived, typed table per [SyncProjection] so callers can run
/// real `WHERE` / `ORDER BY` queries. Because the typed tables are derived, the
/// store can (re)build them from the blob automatically — so changing a model's
/// projected fields never requires a hand-written migration.
///
/// `SyncLocalStore` is in `sync_local_store.dart`; a store implements both.
abstract interface class SyncQueryableStore {
  /// Creates or migrates the typed tables for [projections] and backfills them
  /// from the existing records. Safe to call on every start; additive changes
  /// are applied in place, incompatible ones rebuild the table from the blob.
  Future<void> configureProjections(List<SyncProjection> projections);

  /// Runs a query against [type]'s projected table and returns the matching
  /// records (tombstones excluded).
  ///
  /// [where] / [orderBy] are raw SQL fragments over the projected column names;
  /// [whereArgs] fills `?` placeholders in [where]. Throws [StateError] if
  /// [type] has no configured projection.
  Future<List<SyncRecord>> queryProjection(
    String type, {
    String? where,
    List<Object?> whereArgs,
    String? orderBy,
    int? limit,
  });
}
