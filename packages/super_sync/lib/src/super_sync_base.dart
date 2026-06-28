import 'dart:async';

import 'package:super_sync/src/adapter_registry.dart';
import 'package:super_sync/src/sync_conflict.dart';
import 'package:super_sync/src/sync_engine.dart';
import 'package:super_sync/src/sync_entity_adapter.dart';
import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_remote.dart';
import 'package:super_sync/src/sync_repository.dart';
import 'package:super_sync/src/sync_status.dart';

/// The entry point. Declare a [collection] per model and use it like a normal
/// remote API — reads are instant and offline, writes sync in the background,
/// and the local database stays invisible.
///
/// The simple path — no adapter class, no `register`, no `start`:
///
/// ```dart
/// final db = SuperSync(store: store, remote: myRemote);
///
/// final todos = db.collection<Todo>(
///   id: (t) => t.id,
///   toJson: (t) => t.toJson(),
///   fromJson: Todo.fromJson,
/// );
///
/// await todos.save(Todo(id: 't1', title: 'Buy milk')); // instant, offline-ok
/// final all = await todos.all();                        // local, instant
/// todos.stream().listen(render);                        // reactive
/// ```
///
/// The first call to any collection method opens the store and starts syncing
/// automatically. Prefer to wire adapters explicitly? [register] and [start]
/// are still available.
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
  Future<void>? _startup;

  /// Opens the store/engine exactly once, memoizing the result, so the first
  /// use of any collection transparently starts everything.
  Future<void> _ensureStarted() => _startup ??= start();

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

  /// Declares a synced collection for model [T] with inline JSON — no adapter
  /// class, no `register`, no `start`.
  ///
  /// [id] extracts the entity's stable id, [toJson] / [fromJson] (re)serialize
  /// it. [type] is the wire type name; it defaults to the model's type name, but
  /// pass it explicitly if you obfuscate/minify, since the name must stay stable
  /// across releases. Returns the typed [SyncRepository]; calling [collection]
  /// again for the same [T] returns the same repository.
  ///
  /// ```dart
  /// final todos = db.collection<Todo>(
  ///   id: (t) => t.id,
  ///   toJson: (t) => t.toJson(),
  ///   fromJson: Todo.fromJson,
  /// );
  /// ```
  SyncRepository<T> collection<T>({
    required String Function(T value) id,
    required Map<String, Object?> Function(T value) toJson,
    required T Function(Map<String, Object?> json) fromJson,
    String? type,
    ConflictResolver<T>? conflictResolver,
  }) {
    final wireType = type ?? T.toString();
    if (_registry.byName(wireType) == null) {
      _registry.register<T>(
        _InlineAdapter<T>(
          type: wireType,
          id: id,
          toJson: toJson,
          fromJson: fromJson,
        ),
        resolver: conflictResolver,
      );
    }
    return repository<T>();
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
            ensureStarted: _ensureStarted,
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

/// An adapter built from inline closures, so a model needs no adapter class.
/// Backs [SuperSync.collection].
class _InlineAdapter<T> implements SyncEntityAdapter<T> {
  _InlineAdapter({
    required this.type,
    required String Function(T value) id,
    required Map<String, Object?> Function(T value) toJson,
    required T Function(Map<String, Object?> json) fromJson,
  }) : _id = id,
       _toJson = toJson,
       _fromJson = fromJson;

  @override
  final String type;
  final String Function(T value) _id;
  final Map<String, Object?> Function(T value) _toJson;
  final T Function(Map<String, Object?> json) _fromJson;

  @override
  String idOf(T value) => _id(value);

  @override
  Map<String, Object?> encode(T value) => _toJson(value);

  @override
  T decode(Map<String, Object?> data) => _fromJson(data);
}
