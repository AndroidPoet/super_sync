import 'dart:async';

import 'package:super_sync/src/adapter_registry.dart';
import 'package:super_sync/src/sync_engine.dart';
import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_mutation.dart';
import 'package:super_sync/src/sync_operation.dart';
import 'package:super_sync/src/sync_pager.dart';
import 'package:super_sync/src/sync_record.dart';

/// The typed, model-facing API. One repository per registered type; the same
/// surface works for every model.
abstract interface class SyncRepository<T> {
  /// A reactive list of all live entities, re-emitted on every change.
  Stream<List<T>> watchAll();

  /// A reactive view of one entity (`null` once deleted/absent).
  Stream<T?> watch(String id);

  /// A keyset-paged, reactive window for infinite scroll.
  SyncPager<T> paged({int pageSize = 30});

  /// All live entities, read once.
  Future<List<T>> getAll();

  /// One entity, or `null`.
  Future<T?> get(String id);

  /// Writes [value] locally (optimistic) and queues it for sync.
  Future<void> save(T value);

  /// Writes many [values] locally (optimistic) and queues them.
  Future<void> saveAll(List<T> values);

  /// Tombstones the entity locally and queues the delete.
  Future<void> delete(String id);

  /// Forces a sync cycle now.
  Future<void> sync();

  // --- Plain-API aliases (read like a normal remote client) ----------------

  /// Reads all live entities once. Alias for [getAll].
  Future<List<T>> all();

  /// A reactive list of all live entities. Alias for [watchAll].
  Stream<List<T>> stream();

  /// Deletes the entity with [id]. Alias for [delete].
  Future<void> remove(String id);
}

/// The default [SyncRepository] over a [SyncLocalStore] and [SyncEngine].
class DefaultSyncRepository<T> implements SyncRepository<T> {
  /// Creates a repository for [entity].
  DefaultSyncRepository({
    required RegisteredEntity entity,
    required SyncLocalStore store,
    required SyncEngine engine,
    bool autoSync = true,
    Future<void> Function()? ensureStarted,
  }) : _entity = entity,
       _store = store,
       _engine = engine,
       _autoSync = autoSync,
       _ensureStarted = ensureStarted;

  final RegisteredEntity _entity;
  final SyncLocalStore _store;
  final SyncEngine _engine;
  final bool _autoSync;
  final Future<void> Function()? _ensureStarted;

  /// Lazily opens the store/engine on first use, so callers never have to call
  /// `start()` themselves — the local database stays invisible.
  Future<void> _ready() async {
    final ensure = _ensureStarted;
    if (ensure != null) await ensure();
  }

  static int _seq = 0;
  String _newId(String entityId) =>
      '${DateTime.now().microsecondsSinceEpoch}-${_seq++}-$entityId';

  String get _type => _entity.type;
  T _decode(Map<String, Object?> data) => _entity.decode(data) as T;

  @override
  Stream<List<T>> watchAll() async* {
    await _ready();
    yield* _store
        .watchAll(_type)
        .map((rows) => rows.map((r) => _decode(r.data)).toList());
  }

  @override
  Stream<T?> watch(String id) async* {
    await _ready();
    yield* _store
        .watchRecord(_type, id)
        .map((r) => r == null ? null : _decode(r.data));
  }

  @override
  SyncPager<T> paged({int pageSize = 30}) => SyncPager<T>(
    store: _store,
    type: _type,
    decode: _decode,
    pageSize: pageSize,
    ensureStarted: _ensureStarted,
  );

  @override
  Future<List<T>> getAll() async {
    await _ready();
    final rows = await _store.readAll(_type);
    return rows.map((r) => _decode(r.data)).toList();
  }

  @override
  Future<T?> get(String id) async {
    await _ready();
    final r = await _store.readRecord(_type, id);
    return (r == null || r.deleted) ? null : _decode(r.data);
  }

  @override
  Future<List<T>> all() => getAll();

  @override
  Stream<List<T>> stream() => watchAll();

  @override
  Future<void> remove(String id) => delete(id);

  @override
  Future<void> save(T value) async {
    await _ready();
    final data = _entity.encode(value);
    final id = _entity.idOf(value);
    final existing = await _store.readRecord(_type, id);
    final isCreate = existing == null || existing.deleted;
    final record = SyncRecord(
      type: _type,
      id: id,
      data: data,
      localVersion: (existing?.localVersion ?? 0) + 1,
      serverVersion: existing?.serverVersion,
      updatedAt: DateTime.now(),
    );
    await _store.enqueue(
      SyncMutation(
        id: _newId(id),
        idempotencyKey: _newId(id),
        entityType: _type,
        entityId: id,
        operation: isCreate ? SyncOperation.create : SyncOperation.update,
        payload: data,
        baseVersion: existing?.serverVersion,
        createdAt: DateTime.now(),
      ),
      record,
    );
    _triggerSync();
  }

  @override
  Future<void> saveAll(List<T> values) async {
    for (final v in values) {
      await save(v);
    }
  }

  @override
  Future<void> delete(String id) async {
    await _ready();
    final existing = await _store.readRecord(_type, id);
    if (existing == null) return;
    final record = existing.copyWith(
      deleted: true,
      localVersion: existing.localVersion + 1,
      updatedAt: DateTime.now(),
    );
    await _store.enqueue(
      SyncMutation(
        id: _newId(id),
        idempotencyKey: _newId(id),
        entityType: _type,
        entityId: id,
        operation: SyncOperation.delete,
        payload: const {},
        baseVersion: existing.serverVersion,
        createdAt: DateTime.now(),
      ),
      record,
    );
    _triggerSync();
  }

  @override
  Future<void> sync() async {
    await _ready();
    await _engine.sync();
  }

  void _triggerSync() {
    if (_autoSync) unawaited(_engine.sync());
  }
}
