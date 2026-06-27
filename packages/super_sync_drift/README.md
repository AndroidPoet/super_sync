<h1 align="center">super_sync_drift</h1>

<p align="center">
A durable, SQLite-backed local store for
<a href="https://pub.dev/packages/super_sync">super_sync</a>, built on Drift.
</p>

---

[`super_sync`](https://pub.dev/packages/super_sync) ships with an in-memory
store for tests and prototypes. `super_sync_drift` is the **persistent** store:
records, the outbox and sync cursors all live in SQLite and survive restarts.

It's behaviourally identical to the in-memory store — same monotonic-apply
guard, per-entity outbox coalescing and keyset pagination — and reactivity rides
Drift's own query streams, so `watchAll` re-emits on every relevant change with
no manual notification.

## Usage

```dart
import 'package:drift_flutter/drift_flutter.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_drift/super_sync_drift.dart';

final db = SuperSyncDatabase(driftDatabase(name: 'app'));

final sync = SuperSync(
  store: DriftSyncLocalStore(db),
  remote: MySyncRemote(),
)..register(TodoSyncAdapter());

await sync.start();
```

That's the only change from the in-memory example — swap
`InMemorySyncLocalStore()` for `DriftSyncLocalStore(db)` and your data is now
durable.

## Connecting the database

`SuperSyncDatabase` takes any Drift `QueryExecutor`:

- **Flutter (recommended):** `driftDatabase(name: 'app')` from
  `package:drift_flutter` (bundles `sqlite3_flutter_libs` + `path_provider`).
- **Dart VM / tests:** `NativeDatabase.memory()` or `NativeDatabase(File(path))`
  from `package:drift/native.dart`.

## Prefer a different database?

The store is an interface (`SyncLocalStore`). Drift is one implementation; you
can back super_sync with sqflite, Hive, Isar or raw SQLite by implementing the
same interface. Drift is the recommended default because it provides reactive
query streams out of the box — with a store like sqflite you'd implement
`watchAll` / `watchRecord` yourself via a change notifier.

## License

Apache-2.0 © androidpoet (Ranbir Singh)
