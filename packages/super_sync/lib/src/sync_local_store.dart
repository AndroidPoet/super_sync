import 'package:meta/meta.dart';
import 'package:super_sync/src/sync_mutation.dart';
import 'package:super_sync/src/sync_record.dart';

/// An opaque keyset cursor for paging local records.
///
/// Keyset (not offset) paging keeps deep pages O(page size): the store seeks
/// directly past [lastId] instead of counting rows. Treat it as opaque.
@immutable
class SyncPageToken {
  /// Creates a page token positioned after [lastId].
  const SyncPageToken(this.lastId);

  /// The id of the last record on the previous page.
  final String lastId;

  @override
  bool operator ==(Object other) =>
      other is SyncPageToken && other.lastId == lastId;

  @override
  int get hashCode => lastId.hashCode;
}

/// One page of records plus the cursor for the next page.
@immutable
class SyncRecordPage {
  /// Creates a record page.
  const SyncRecordPage({required this.records, this.nextPageToken});

  /// The records in this page, ordered by id.
  final List<SyncRecord> records;

  /// The token to fetch the next page, or `null` if this is the last page.
  final SyncPageToken? nextPageToken;

  /// Whether more records remain after this page.
  bool get hasMore => nextPageToken != null;
}

/// Durable, model-agnostic storage for records, the outbox and sync cursors.
///
/// The engine holds exactly one store. An in-memory implementation ships in the
/// box ([InMemorySyncLocalStore]); a Drift implementation lives in
/// `super_sync_drift`. All writes that change records must wake the
/// corresponding [watchAll] / [watchRecord] streams.
abstract interface class SyncLocalStore {
  /// Prepares the store (open files, run migrations). Called once by
  /// `SuperSync.start`.
  Future<void> initialize();

  // --- Records ---------------------------------------------------------------

  /// Reads one record, or `null` if absent. Tombstones are returned so callers
  /// can observe deletions; filter on [SyncRecord.deleted] as needed.
  Future<SyncRecord?> readRecord(String type, String id);

  /// Reads every live record of [type], ordered by id.
  Future<List<SyncRecord>> readAll(String type, {bool includeDeleted = false});

  /// Reads one keyset page of [type], ordered by id, starting after [after].
  Future<SyncRecordPage> readPage(
    String type, {
    SyncPageToken? after,
    int limit = 50,
    bool includeDeleted = false,
  });

  /// Counts live records of [type].
  Future<int> count(String type, {bool includeDeleted = false});

  /// Writes [record], honouring the monotonic-apply guard (a write whose
  /// version does not advance the stored record is ignored). Wakes watchers.
  Future<void> putRecord(SyncRecord record);

  /// Hard-deletes a record (used by tombstone GC, not by user deletes). Wakes
  /// watchers.
  Future<void> removeRecord(String type, String id);

  // --- Reactivity ------------------------------------------------------------

  /// A broadcast stream of all live records of [type], re-emitted on every
  /// change. Drives reactive reads and pagination.
  Stream<List<SyncRecord>> watchAll(String type);

  /// A broadcast stream of a single record, re-emitted on change (`null` once
  /// deleted/absent).
  Stream<SyncRecord?> watchRecord(String type, String id);

  // --- Outbox ----------------------------------------------------------------

  /// Atomically applies the optimistic [record] and enqueues [mutation] in one
  /// transaction, then wakes watchers. The outbox is deduped per entity id.
  Future<void> enqueue(SyncMutation mutation, SyncRecord record);

  /// Returns up to [limit] mutations eligible to push: retry count below
  /// [maxRetries] and [SyncMutation.nextRetryAt] in the past, ordered oldest
  /// first, starting after [after] (keyset drain).
  Future<List<SyncMutation>> pendingMutations({
    int limit = 500,
    SyncPageToken? after,
    int maxRetries = 5,
    DateTime? now,
  });

  /// Removes acknowledged mutations from the outbox.
  Future<void> removeMutations(Iterable<String> mutationIds);

  /// Advances retry bookkeeping for rejected mutations (count +1, backoff).
  Future<void> rescheduleMutations(Iterable<SyncMutation> mutations);

  /// Number of mutations still pushable (retry count below [maxRetries]).
  Future<int> pendingCount({int maxRetries = 5});

  /// Number of mutations that exhausted [maxRetries] and are parked.
  Future<int> deadLetterCount({int maxRetries = 5});

  // --- Cursors ---------------------------------------------------------------

  /// Reads the pull cursor stored under [key], or `null` if never set.
  Future<String?> readCursor(String key);

  /// Persists the pull [cursor] under [key].
  Future<void> writeCursor(String key, String? cursor);

  // --- Maintenance -----------------------------------------------------------

  /// Hard-deletes acknowledged tombstones older than [olderThan] that are not
  /// still referenced by the outbox. Returns the number purged.
  Future<int> purgeTombstones({required DateTime olderThan});

  /// Releases resources.
  Future<void> close();
}
