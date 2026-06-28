import 'package:super_sync/src/sync_projection.dart';
import 'package:super_sync/src/sync_query.dart';
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
  /// Optionally pre-warms the typed columns for [projections] at startup, so the
  /// first query on those fields doesn't pay the lazy materialization cost. This
  /// is purely a performance hint — fields are materialized on demand anyway.
  Future<void> configureProjections(List<SyncProjection> projections);

  /// Runs [spec] against [type] and returns the matching records (tombstones
  /// excluded).
  ///
  /// Any field referenced by the spec is materialized into an indexed column on
  /// first use (backfilled from the JSON blob), so no schema declaration is
  /// required. A spec with no field references reads straight from the blob.
  Future<List<SyncRecord>> queryProjection(String type, SyncQuerySpec spec);
}
