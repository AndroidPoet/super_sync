import 'package:meta/meta.dart';
import 'package:super_sync/src/sync_operation.dart';

/// A single queued local change, persisted in the outbox until the server
/// acknowledges it.
///
/// Mutations are model-agnostic: the [payload] is the encoded entity (or the
/// changed fields) and the engine batches mutations of *different* entity types
/// into one push. [idempotencyKey] lets the server dedupe retries, and
/// [baseVersion] carries the server revision the change was made against for
/// optimistic-concurrency conflict detection.
@immutable
class SyncMutation {
  /// Creates a mutation.
  const SyncMutation({
    required this.id,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.baseVersion,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  /// Unique id of this mutation (the outbox primary key).
  final String id;

  /// Stable key the server uses to dedupe a retried mutation. Survives retries
  /// so re-delivery is safe.
  final String idempotencyKey;

  /// The entity type this change targets, e.g. `'todo'`.
  final String entityType;

  /// The id of the entity this change targets.
  final String entityId;

  /// What kind of change this is.
  final SyncOperation operation;

  /// The encoded change payload. Empty for [SyncOperation.delete].
  final Map<String, Object?> payload;

  /// The server revision the change was based on, or `null` for a create.
  final int? baseVersion;

  /// How many times delivery has been attempted.
  final int retryCount;

  /// Earliest time the engine should retry this mutation (exponential backoff).
  /// `null` means "eligible now".
  final DateTime? nextRetryAt;

  /// When the mutation was enqueued.
  final DateTime createdAt;

  /// Returns a copy with retry bookkeeping advanced.
  SyncMutation copyWith({
    int? retryCount,
    DateTime? nextRetryAt,
    int? baseVersion,
  }) {
    return SyncMutation(
      id: id,
      idempotencyKey: idempotencyKey,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      baseVersion: baseVersion ?? this.baseVersion,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'SyncMutation(${operation.name} $entityType/$entityId '
      'base=$baseVersion try=$retryCount)';
}
