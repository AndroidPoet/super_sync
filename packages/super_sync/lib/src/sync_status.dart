import 'package:meta/meta.dart';

/// What the engine is doing right now.
enum SyncPhase {
  /// Nothing in flight; the outbox may still hold pending or dead-lettered work.
  idle,

  /// A push/pull cycle is running.
  syncing,

  /// The last cycle failed; [SyncStatus.error] holds the cause.
  error,
}

/// An immutable snapshot of sync progress, emitted on [SuperSync.status].
@immutable
class SyncStatus {
  /// Creates a status snapshot.
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingChanges = 0,
    this.deadLettered = 0,
    this.lastSyncedAt,
    this.error,
  });

  /// The current phase.
  final SyncPhase phase;

  /// Number of mutations still waiting to be pushed (excludes dead-lettered).
  final int pendingChanges;

  /// Number of mutations that exhausted their retries and are parked.
  final int deadLettered;

  /// When the last cycle completed successfully, or `null` if never.
  final DateTime? lastSyncedAt;

  /// The cause of the last failure, present when [phase] is [SyncPhase.error].
  final Object? error;

  /// Whether everything local has reached the server.
  bool get isFullySynced => pendingChanges == 0 && deadLettered == 0;

  /// Returns a copy with the given fields replaced.
  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingChanges,
    int? deadLettered,
    DateTime? lastSyncedAt,
    Object? error,
    bool clearError = false,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      deadLettered: deadLettered ?? this.deadLettered,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() =>
      'SyncStatus(${phase.name}, pending=$pendingChanges, '
      'dead=$deadLettered)';
}
