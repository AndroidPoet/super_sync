import 'package:meta/meta.dart';
import 'package:super_sync/src/sync_mutation.dart';
import 'package:super_sync/src/sync_operation.dart';

/// The single seam between the engine and any backend.
///
/// Super Sync never depends on REST, GraphQL or any vendor SDK directly. A
/// backend is "supported" the moment someone implements this two-method
/// interface; the engine is unchanged. Implementations should be stateless and
/// throw on transport failure — the engine catches, backs off and retries.
abstract interface class SyncRemote {
  /// Uploads a batch of (possibly mixed-type) [mutations] and returns a
  /// per-mutation acknowledgement. The order of [PushResponse.results] need not
  /// match the input; results are matched by [MutationResult.mutationId].
  Future<PushResponse> push(List<SyncMutation> mutations);

  /// Downloads changes since [cursor]. The engine calls this repeatedly,
  /// advancing the cursor, until [PullResponse.hasMore] is `false` — so each
  /// call should return one bounded page (keyset paging server-side).
  ///
  /// [entityTypes], when given, scopes the pull to those types. [limit] is a
  /// hint for the page size.
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  });
}

/// The outcome of a [SyncRemote.push].
@immutable
class PushResponse {
  /// Creates a push response.
  const PushResponse(this.results);

  /// One result per submitted mutation.
  final List<MutationResult> results;
}

/// How the server handled a single mutation.
enum MutationStatus {
  /// The change was applied; [MutationResult.serverVersion] is the new revision.
  applied,

  /// The change collided with a newer server revision;
  /// [MutationResult.remoteData] and [MutationResult.serverVersion] describe the
  /// server's current state for conflict resolution.
  conflict,

  /// The change was refused (validation, auth, transient). The engine backs off
  /// and retries until the dead-letter ceiling.
  rejected,
}

/// The server's acknowledgement of one mutation.
@immutable
class MutationResult {
  /// Creates a mutation result.
  const MutationResult({
    required this.mutationId,
    required this.status,
    this.serverVersion,
    this.remoteData,
    this.error,
  });

  /// The [SyncMutation.id] this result corresponds to.
  final String mutationId;

  /// How the server handled it.
  final MutationStatus status;

  /// The resulting (or current, on conflict) server revision.
  final int? serverVersion;

  /// The server's current entity state, present on [MutationStatus.conflict].
  final Map<String, Object?>? remoteData;

  /// An optional human-readable reason, present on [MutationStatus.rejected].
  final String? error;
}

/// The outcome of a [SyncRemote.pull].
@immutable
class PullResponse {
  /// Creates a pull response.
  const PullResponse({
    required this.changes,
    this.nextCursor,
    this.hasMore = false,
  });

  /// The changes in this page, in server order.
  final List<RemoteChange> changes;

  /// The cursor to pass to the next [SyncRemote.pull]. Opaque to the engine.
  final String? nextCursor;

  /// Whether more pages remain after this one.
  final bool hasMore;
}

/// A single change streamed down from the server.
@immutable
class RemoteChange {
  /// Creates a remote change.
  const RemoteChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.serverVersion,
    this.data,
  });

  /// The entity type this change targets.
  final String entityType;

  /// The id of the entity that changed.
  final String entityId;

  /// Whether the entity was upserted ([SyncOperation.create] /
  /// [SyncOperation.update]) or [SyncOperation.delete]d.
  final SyncOperation operation;

  /// The server revision after this change. Drives the monotonic-apply guard.
  final int serverVersion;

  /// The full entity state, present for upserts and `null` for deletes.
  final Map<String, Object?>? data;
}
