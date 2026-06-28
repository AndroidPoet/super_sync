<h1 align="center">Super Sync</h1>

<p align="center">
A generic, offline-first sync engine for Dart & Flutter.<br>
Register any model, write locally, synchronize through any backend — against any local database.
</p>

<p align="center">
<a href="https://github.com/AndroidPoet/super_sync/actions/workflows/ci.yml"><img src="https://github.com/AndroidPoet/super_sync/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License">
<img src="https://img.shields.io/badge/style-very__good__analysis-B22C89" alt="very_good_analysis">
</p>

---

Super Sync doesn't know what a `Todo`, `User` or `Message` is. It understands
only **entities, ids, operations, payloads, versions and cursors** — so the
*same* engine syncs every model in your app through one API, against any backend,
on top of any local database.

```dart
final sync = SuperSync(
  store: DriftSyncLocalStore(db), // or sqflite / in-memory — your choice
  remote: MySyncRemote(),         // your backend, behind one interface
)
  ..register(TodoSyncAdapter())
  ..register(UserSyncAdapter());

await sync.start();

final todos = sync.repository<Todo>();
await todos.save(const Todo(id: 't1', title: 'Buy milk')); // optimistic, instant
todos.watchAll();                                          // reactive stream
```

## Table of contents

- [Why](#why)
- [How it fits together](#how-it-fits-together)
- [The monorepo](#the-monorepo)
- [Quick start](#quick-start)
- [Choosing a local database](#choosing-a-local-database)
- [Code generation from OpenAPI](#code-generation-from-openapi)
- [Built to scale](#built-to-scale)
- [Architecture](#architecture)
- [Examples](#examples)
- [Development](#development)
- [License](#license)

## Why

- **Generic.** One engine, every model. Adding a model is a ~10-line adapter —
  the engine code never changes.
- **Backend-agnostic.** REST, GraphQL, Supabase, Firebase, a Cloudflare Worker —
  a backend is supported the moment you implement `SyncRemote` (two methods).
- **Database-agnostic.** The local store is an interface. Use the bundled
  in-memory store, Drift/SQLite, or sqflite — or implement your own over Hive,
  Isar, ObjectBox, etc.
- **Offline-first.** Writes hit local storage and an outbox first; the UI updates
  immediately and the network catches up.
- **Built to scale**, not just to demo — keyset pagination, chunked pull, paged
  push, outbox coalescing, exponential backoff + dead-letter, and a
  monotonic-apply guard. [Details below](#built-to-scale).

## How it fits together

You implement (or generate) two small things and pick a store. The engine does
the rest.

```
        your model                  your backend
            │                            │
   SyncEntityAdapter<T>             SyncRemote
   (type/id/encode/decode)        (push / pull)
            │                            │
            └──────────► SyncEngine ◄────┘
                             │
                       SyncLocalStore
                             │
        ┌────────────────────┼────────────────────┐
   InMemory…            Drift (SQLite)          sqflite
   (tests/proto)        (reactive, default)     (popular plugin)
```

- A **`SyncEntityAdapter<T>`** is the only thing a model implements:
  `type`, `idOf`, `encode`, `decode`.
- A **`SyncRemote`** is the single backend seam: `push(mutations)` and
  `pull(cursor)`.
- A **`SyncLocalStore`** is the persistence seam — pick one of the bundled stores
  or write your own.
- The **`SyncEngine`** (behind the `SuperSync` facade) orchestrates the outbox,
  batching, conflict resolution, pagination and retries.

## The monorepo

A Dart **pub workspace** (native `resolution: workspace`, one lockfile) of
independently publishable packages:

| Package | Role | Status |
| --- | --- | --- |
| [`super_sync`](packages/super_sync) | Pure-Dart core engine — adapters, repository, engine, pager, in-memory store | ✅ |
| [`super_sync_drift`](packages/super_sync_drift) | Durable [Drift](https://pub.dev/packages/drift)/SQLite store — **reactive query streams for free** (recommended default for persistence) | ✅ |
| [`super_sync_sqflite`](packages/super_sync_sqflite) | Durable [sqflite](https://pub.dev/packages/sqflite)/SQLite store — for apps already on the most popular plugin | ✅ |
| [`super_sync_codegen`](packages/super_sync_codegen) | Generate the whole data layer (models + adapters + wiring) from an OpenAPI 3 spec | ✅ |
| [`apps/pokedex`](apps/pokedex) | Flutter **macOS desktop** demo — live PokeAPI pull into a persistent local DB, infinite scroll, stress test | ✅ |
| `super_sync_hive` | Pure-Dart Hive store (reactive `watch()`) | *planned* |
| `super_sync_flutter` | App-lifecycle & connectivity sync triggers | *planned* |

Each package versions and releases on its own. Core and the two stores all pass
`dart pub publish --dry-run` with **0 warnings**.

## Quick start

### 1. Add a model adapter

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

### 2. Connect a backend

```dart
abstract interface class SyncRemote {
  Future<PushResponse> push(List<SyncMutation> mutations);
  Future<PullResponse> pull({String? cursor, Set<String>? entityTypes, int? limit});
}
```

`push` uploads a batch of mixed-type mutations and returns a per-mutation ack
(`applied` / `conflict` / `rejected`). `pull` returns one bounded page of changes
plus a cursor; the engine calls it until `hasMore` is false.

### 3. Pick a store, register, start

```dart
final sync = SuperSync(store: store, remote: remote)
  ..register(TodoSyncAdapter());
await sync.start();
```

### 4. Use the repository

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

Conflicts are detected by **version** (`baseVersion` vs the server revision), so
the engine never depends on clock agreement between devices. The strategy is a
global default (`serverWins` / `clientWins`), overridable per entity with a
custom `ConflictResolver`.

## Choosing a local database

The local store is the `SyncLocalStore` interface — every bundled store behaves
identically (same monotonic-apply guard, outbox coalescing and keyset
pagination). They differ only in persistence and how reactivity is delivered.

| Store | Package | Persistent | Reactivity | Best for |
| --- | --- | --- | --- | --- |
| `InMemorySyncLocalStore` | `super_sync` | ❌ | broadcast controllers | tests, prototypes |
| `DriftSyncLocalStore` | `super_sync_drift` | ✅ SQLite | **native query streams** | **most apps** (recommended) |
| `SqfliteSyncLocalStore` | `super_sync_sqflite` | ✅ SQLite | manual change-notifier | apps already on `sqflite` |

> **Reactivity note.** Drift gives reactive query streams out of the box, so
> `watchAll` re-emits with zero extra machinery. sqflite has no query streams, so
> that store re-implements reactivity with a per-type change notifier (every
> write pokes a tick and the stream re-queries). Both are correct and smooth;
> Drift is the recommended default because it's free.

Swapping stores is a one-line change:

```dart
// in-memory → Drift
store: InMemorySyncLocalStore()   →   store: DriftSyncLocalStore(db)
// in-memory → sqflite
store: InMemorySyncLocalStore()   →   store: SqfliteSyncLocalStore(db)
```

Want Hive, Isar, ObjectBox or raw SQLite? Implement `SyncLocalStore` and you're
done — the engine is unchanged.

### No per-model DB schema, ever

Every store keeps data in **generic tables** (`sync_records`, `sync_mutations`,
`sync_cursors`) holding JSON payloads. Adding or changing a model is never a
database migration — re-generate or edit your adapter and ship.

## Code generation from OpenAPI

Point [`super_sync_codegen`](packages/super_sync_codegen) at an OpenAPI 3 spec
and get your **entire data layer** as one file:

```sh
dart run super_sync_codegen:super_sync_gen openapi.yaml lib/app_models.g.dart
```

For every schema with an `id` property it emits an immutable model, a
`SyncEntityAdapter`, a single `registerSuperSyncModels(sync)` call, and an
`AppSync` facade with a typed repository per model. Then the whole layer comes up
in one call — over *any* store:

```dart
final app = await openAppSync(
  store: DriftSyncLocalStore(db), // or SqfliteSyncLocalStore / InMemory…
  remote: MyRemote(),
);

await app.todos.save(const Todo(id: 't1', title: 'Buy milk', completed: false));
app.users.watchAll();
app.status.listen(print);
await app.syncNow();
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
| Concurrency | single-flight sync via an async `Lock` — no overlapping cycles |

These aren't claims — they're verified. The demo app pulls live data into a
persistent DB, survives restart (loads instantly with no network), and a stress
test runs **200 concurrent writes + 3 concurrent syncs** with consistent counts
and **no deadlock**.

## Architecture

Core concepts (in `packages/super_sync/lib/src`):

- **`SyncRecord`** — the generic envelope: `type`, `id`, JSON `data`, a monotonic
  `localVersion`, a `serverVersion`, a `deleted` tombstone, `updatedAt`.
- **`SyncMutation`** + **`SyncOperation`** — an outbox entry (create/update/delete)
  with an idempotency key and `baseVersion` for conflict detection.
- **`SyncEntityAdapter<T>`** — the per-model seam (`type`/`idOf`/`encode`/`decode`).
- **`SyncRemote`** — the backend seam (`push`/`pull`).
- **`SyncLocalStore`** — the persistence seam (records + outbox + cursor + GC,
  with keyset paging).
- **`SyncEngine`** — paged conflict-aware push with backoff/dead-letter, chunked
  local-wins-skip pull, single-flight via `package:synchronized`.
- **`SyncPager<T>`** — keyset + reactive window for smooth infinite scroll.
- **`SuperSync`** — the facade: `register<T>` / `start` / `repository<T>` /
  `sync` / `status` / `purgeTombstones`.

Design choices: **version-based** conflicts (not clock/LWW — web-int safe and no
clock dependency); writes are atomic optimistic record + outbox enqueue;
un-pushed local work is skipped on pull so the server can't clobber it; outbox
coalescing (create+delete of an unsynced entity is a net no-op).

## Examples

- **`packages/super_sync/example`** — console demo syncing against the **live
  PokeAPI** (read-only `SyncRemote`, keyset pull, local cache, reactive pager).
- **`apps/pokedex`** — Flutter macOS desktop app: live pull into a Drift DB,
  infinite-scroll grid, status bar, and a concurrency stress button.

## Development

```sh
flutter pub get          # resolves the whole workspace (includes the Flutter app)

# format / analyze / test the libraries
dart format --output=none --set-exit-if-changed packages/*/lib packages/*/test
dart analyze packages/super_sync packages/super_sync_drift packages/super_sync_sqflite packages/super_sync_codegen
dart test packages/super_sync
dart test packages/super_sync_drift
dart test packages/super_sync_sqflite
dart test packages/super_sync_codegen
```

> **Note:** use `flutter pub get` (not `dart pub get`) at the root — the workspace
> contains a Flutter app, so the Dart-only resolver can't satisfy it. CI does the
> same via `subosito/flutter-action`.

Lints are [`very_good_analysis`](https://pub.dev/packages/very_good_analysis).
See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

Apache-2.0 © androidpoet (Ranbir Singh)
