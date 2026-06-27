<h1 align="center">super_sync_sqflite</h1>

<p align="center">
A durable, SQLite-backed local store for
<a href="https://pub.dev/packages/super_sync">super_sync</a>, built on
<a href="https://pub.dev/packages/sqflite">sqflite</a>.
</p>

---

If your app already uses [`sqflite`](https://pub.dev/packages/sqflite) — the most
popular SQLite plugin for Flutter — this is the persistent store for you.
Records, the outbox and sync cursors all live in SQLite and survive restarts.

It's behaviourally identical to the in-memory and Drift stores — same
monotonic-apply guard, per-entity outbox coalescing and keyset pagination.

> **Reactivity note.** sqflite has no reactive query streams, so this store
> implements `watchAll` / `watchRecord` with a manual per-type change notifier:
> every write pokes a tick and the stream re-queries. It's correct and smooth,
> but if you want reactivity for free, [`super_sync_drift`](https://pub.dev/packages/super_sync_drift)
> rides Drift's own query streams.

## Usage

```dart
import 'package:sqflite/sqflite.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_sqflite/super_sync_sqflite.dart';

final db = await openDatabase('app.db');

final sync = SuperSync(
  store: SqfliteSyncLocalStore(db),
  remote: MySyncRemote(),
)..register(TodoSyncAdapter());

await sync.start();
```

That's the only change from the in-memory example — swap
`InMemorySyncLocalStore()` for `SqfliteSyncLocalStore(db)` and your data is now
durable. `initialize()` (called by `start()`) creates the tables; you don't need
an `onCreate` callback.

## Connecting the database

`SqfliteSyncLocalStore` takes any open sqflite `Database`:

- **Flutter (recommended):** `openDatabase(...)` from `package:sqflite`.
- **Desktop / Dart VM / tests:** `databaseFactoryFfi.openDatabase(...)` from
  `package:sqflite_common_ffi` (call `sqfliteFfiInit()` first).

The store keeps everything in three generic tables (`sync_records`,
`sync_mutations`, `sync_cursors`) — no per-model schema, so adding a model is
never a database migration.

## License

Apache-2.0 © androidpoet (Ranbir Singh)
