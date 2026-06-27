/// The default policy applied when a push collides with a newer server
/// revision and no per-entity [ConflictResolver] is registered.
enum ConflictStrategy {
  /// Discard the local change and accept the server's version.
  serverWins,

  /// Re-apply the local change on top of the server's revision (last-writer
  /// wins, client side).
  clientWins,
}

/// A custom, per-entity conflict resolver.
///
/// Given the conflicting typed [local] and [remote] values, return the winner
/// (which may be a merge of both). Registered per type via
/// `SuperSync.register(..., conflictResolver: ...)`. Runs on decoded models, so
/// you never touch the raw envelope:
///
/// ```dart
/// sync.register<Todo>(
///   TodoSyncAdapter(),
///   conflictResolver: (local, remote) async =>
///       local.updatedAt.isAfter(remote.updatedAt) ? local : remote,
/// );
/// ```
typedef ConflictResolver<T> = Future<T> Function(T local, T remote);
