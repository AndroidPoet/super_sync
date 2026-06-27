import 'dart:async';

import 'package:super_sync/src/adapter_registry.dart';
import 'package:super_sync/src/sync_conflict.dart';
import 'package:super_sync/src/sync_engine.dart';
import 'package:super_sync/src/sync_entity_adapter.dart';
import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_remote.dart';
import 'package:super_sync/src/sync_repository.dart';
import 'package:super_sync/src/sync_status.dart';

/// The entry point: register any number of models, then read/write each through
/// a typed [SyncRepository] while the engine syncs them generically.
///
/// ```dart
/// final sync = SuperSync(store: InMemorySyncLocalStore(), remote: myRemote)
///   ..register(TodoSyncAdapter())
///   ..register(UserSyncAdapter())
///   ..register(MessageSyncAdapter());
/// await sync.start();
///
/// final todos = sync.repository<Todo>();
/// await todos.save(todo);
/// todos.watchAll();
/// ```
class SuperSync {
  /// Creates a Super Sync instance over [store] and [remote].
  SuperSync({
    required SyncLocalStore store,
    required SyncRemote remote,
    ConflictStrategy conflictStrategy = ConflictStrategy.serverWins,
    SyncConfig config = const SyncConfig(),
    bool autoSync = true,
  }) : _store = store,
       _autoSync = autoSync {
    _engine = SyncEngine(
      store: store,
      remote: remote,
      registry: _registry,
      conflictStrategy: conflictStrategy,
      config: config,
    );
  }

  final SyncLocalStore _store;
  final AdapterRegistry _registry = AdapterRegistry();
  final Map<String, Object> _repositories = {};
  final bool _autoSync;
  late final SyncEngine _engine;
  bool _started = false;

  /// Registers [adapter], optionally with a per-entity [conflictResolver].
  /// Call before [start].
  void register<T>(
    SyncEntityAdapter<T> adapter, {
    ConflictResolver<T>? conflictResolver,
  }) {
    if (_started) {
      throw StateError('Register all adapters before calling start().');
    }
    _registry.register<T>(adapter, resolver: conflictResolver);
  }

  /// Opens the store. Idempotent.
  Future<void> start() async {
    if (_started) return;
    await _store.initialize();
    await _engine.refreshCounts();
    _started = true;
  }

  /// The typed repository for model [T]. Throws if [T] was never registered.
  SyncRepository<T> repository<T>() {
    final entity = _registry.byType<T>();
    return _repositories.putIfAbsent(
          entity.type,
          () => DefaultSyncRepository<T>(
            entity: entity,
            store: _store,
            engine: _engine,
            autoSync: _autoSync,
          ),
        )
        as SyncRepository<T>;
  }

  /// Runs one full push+pull cycle across every registered type.
  Future<void> sync() => _engine.sync();

  /// The live sync status (broadcast; replays the latest value on listen).
  Stream<SyncStatus> get status => _engine.status;

  /// The latest status snapshot.
  SyncStatus get currentStatus => _engine.currentStatus;

  /// Garbage-collects acknowledged tombstones older than [olderThan].
  Future<int> purgeTombstones({
    Duration olderThan = const Duration(days: 30),
  }) => _engine.purgeTombstones(olderThan: olderThan);

  /// Closes the engine and store.
  Future<void> dispose() async {
    await _engine.dispose();
    await _store.close();
  }
}
