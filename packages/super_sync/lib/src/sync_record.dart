import 'package:meta/meta.dart';

/// The engine's generic, model-agnostic view of a single synced entity.
///
/// Super Sync never stores `Todo` or `User` columns. Every model is encoded by
/// its [SyncEntityAdapter] into this envelope: an opaque [data] map keyed by
/// ([type], [id]), plus the bookkeeping the engine needs to converge —
/// [localVersion], [serverVersion] and the [deleted] tombstone flag.
@immutable
class SyncRecord {
  /// Creates a record. [updatedAt] is the local wall-clock time of the last
  /// write; it is used only for display and as a conflict tie-breaker, never as
  /// the sync cursor (versions drive convergence so the engine is clock-safe
  /// and web-int-safe).
  const SyncRecord({
    required this.type,
    required this.id,
    required this.data,
    required this.updatedAt,
    this.localVersion = 1,
    this.serverVersion,
    this.deleted = false,
  });

  /// The registered entity type, e.g. `'todo'`.
  final String type;

  /// The entity's stable identity within its [type].
  final String id;

  /// The encoded payload. Any JSON-compatible map; the engine treats it as
  /// opaque.
  final Map<String, Object?> data;

  /// Monotonically increasing local revision. Bumped on every local write and
  /// used to reject out-of-order applies (the monotonic-apply guard).
  final int localVersion;

  /// The server's revision for this entity, or `null` if it has never synced.
  /// Sent as the `baseVersion` of the next mutation for optimistic-concurrency
  /// conflict detection.
  final int? serverVersion;

  /// Whether this record is a tombstone awaiting server acknowledgement and,
  /// later, garbage collection.
  final bool deleted;

  /// Local time of the last write.
  final DateTime updatedAt;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass [clearServerVersion] to force [serverVersion] back to `null` (a plain
  /// `null` argument cannot distinguish "leave unchanged" from "clear").
  SyncRecord copyWith({
    Map<String, Object?>? data,
    int? localVersion,
    int? serverVersion,
    bool clearServerVersion = false,
    bool? deleted,
    DateTime? updatedAt,
  }) {
    return SyncRecord(
      type: type,
      id: id,
      data: data ?? this.data,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: clearServerVersion
          ? null
          : (serverVersion ?? this.serverVersion),
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SyncRecord &&
      other.type == type &&
      other.id == id &&
      other.localVersion == localVersion &&
      other.serverVersion == serverVersion &&
      other.deleted == deleted &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(type, id, localVersion, serverVersion, deleted, updatedAt);

  @override
  String toString() =>
      'SyncRecord($type/$id v$localVersion'
      '${serverVersion == null ? '' : '→$serverVersion'}'
      '${deleted ? ' deleted' : ''})';
}
