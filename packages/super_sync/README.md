<h1 align="center">Super Sync</h1>

<p align="center">
A generic, offline-first sync engine for Dart.<br>
Register any model, write locally, synchronize through any backend.
</p>

---

Super Sync doesn't know what a `Todo`, `User` or `Message` is. It understands
only **entities, ids, operations, payloads, versions and cursors** — so the same
engine syncs every model in your app through one API, against any backend.

```dart
final sync = SuperSync(
  store: InMemorySyncLocalStore(), // or super_sync_drift for persistence
  remote: MySyncRemote(),          // your backend, behind one interface
)
  ..register(TodoSyncAdapter())
  ..register(UserSyncAdapter())
  ..register(MessageSyncAdapter());

await sync.start();

final todos = sync.repository<Todo>();
await todos.save(const Todo(id: 't1', title: 'Buy milk')); // optimistic, instant
todos.watchAll();                                          // reactive stream
```

## Why

- **Generic.** One engine, every model. Add a model = write a ~10-line adapter.
- **Backend-agnostic.** REST, GraphQL, Supabase, Firebase, a CF Worker — a
  backend is supported the moment you implement `SyncRemote` (two methods). The
  engine never changes.
- **Offline-first.** Writes hit local storage and an outbox first; the UI
  updates immediately and the network catches up.
- **Built to scale**, not just to demo (see below).

## Add a model

```dart
class TodoSyncAdapter implements SyncEntityAdapter<Todo> {
  @override
  String get type => 'todo';

  @override
  String idOf(Todo v) => v.id;

  @override
  Map<String, Object?> encode(Todo v) =>
      {'id': v.id, 'title': v.title, 'done': v.done};

  @override
  Todo decode(Map<String, Object?> d) => Todo(
        id: d['id']! as String,
        title: d['title']! as String,
        done: d['done']! as bool,
      );
}
```

That's all a model needs. The engine handles storage, the outbox, batching,
conflicts and pagination generically.

## The repository

The same surface works for every registered type:

```dart
abstract interface class SyncRepository<T> {
  Stream<List<T>> watchAll();
  Stream<T?> watch(String id);
  SyncPager<T> paged({int pageSize = 30});
  Future<List<T>> getAll();
  Future<T?> get(String id);
  Future<void> save(T value);
  Future<void> saveAll(List<T> values);
  Future<void> delete(String id);
  Future<void> sync();
}
```

## Pagination that stays smooth

`SyncPager<T>` is **keyset-based** (not offset), so loading the 100th page costs
the same as the first, and **reactive**, so optimistic writes and incoming
server changes re-emit the visible window with no manual refresh:

```dart
final pager = todos.paged(pageSize: 30);
pager.pages.listen((page) => render(page.items, hasMore: page.hasMore));

// at the bottom of the list:
await pager.loadMore();
```

## Conflicts

A global default, overridable per entity:

```dart
final sync = SuperSync(
  store: store,
  remote: remote,
  conflictStrategy: ConflictStrategy.serverWins, // or clientWins
);

sync.register<Todo>(
  TodoSyncAdapter(),
  conflictResolver: (local, remote) async =>
      local.updatedAt.isAfter(remote.updatedAt) ? local : remote,
);
```

Conflicts are detected by **version** (`baseVersion` vs the server revision), so
the engine never depends on clock agreement between devices.

## Connect a backend

```dart
abstract interface class SyncRemote {
  Future<PushResponse> push(List<SyncMutation> mutations);
  Future<PullResponse> pull({String? cursor, Set<String>? entityTypes, int? limit});
}
```

`push` uploads a batch of mixed-type mutations and returns a per-mutation ack
(`applied` / `conflict` / `rejected`). `pull` returns one bounded page of
changes plus a cursor; the engine calls it until `hasMore` is false.

## Status

```dart
sync.status.listen((s) {
  print('${s.phase} — ${s.pendingChanges} pending, ${s.deadLettered} parked');
});
```

## Built to scale

| Concern | How |
| --- | --- |
| Large lists | keyset pagination — O(page size) at any depth |
| Large initial sync | chunked pull drains page by page in one cycle |
| Large outbox | paged push in bounded batches |
| Edit bursts | per-entity outbox coalescing → one push, not one per keystroke |
| Flaky network | exponential backoff + dead-letter ceiling |
| Out-of-order delivery | monotonic-apply guard |
| Local edits vs server | un-pushed local work is never clobbered by a pull |

## Packages

| Package | Role |
| --- | --- |
| `super_sync` | pure-Dart core engine (this package) |
| `super_sync_drift` | Drift/SQLite store — reactive query streams (recommended for persistence) |
| `super_sync_sqflite` | sqflite/SQLite store — for apps already on the sqflite plugin |
| `super_sync_codegen` | generate the whole data layer from an OpenAPI 3 spec |
| `super_sync_flutter` | app-lifecycle & connectivity sync triggers *(planned)* |

## License

Apache-2.0 © androidpoet (Ranbir Singh)
