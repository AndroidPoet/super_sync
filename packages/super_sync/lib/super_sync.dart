/// Super Sync — a generic, offline-first sync engine for Dart.
///
/// Register any Dart model through a [SyncEntityAdapter], write locally through
/// a typed [SyncRepository], and synchronize through any backend that
/// implements [SyncRemote]. The engine is model-agnostic, backend-agnostic and
/// built to scale: keyset pagination, chunked pull, paged push, an outbox with
/// exponential backoff and a dead-letter ceiling, and a monotonic-apply guard.
library;

export 'src/in_memory_sync_local_store.dart';
export 'src/super_sync_base.dart';
export 'src/sync_conflict.dart';
export 'src/sync_engine.dart' show SyncConfig;
export 'src/sync_entity_adapter.dart';
export 'src/sync_local_store.dart';
export 'src/sync_mutation.dart';
export 'src/sync_operation.dart';
export 'src/sync_pager.dart';
export 'src/sync_record.dart';
export 'src/sync_remote.dart';
export 'src/sync_repository.dart' show SyncRepository;
export 'src/sync_status.dart';
