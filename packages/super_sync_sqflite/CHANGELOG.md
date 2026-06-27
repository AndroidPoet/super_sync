## 0.1.0

- Initial release.
- `SqfliteSyncLocalStore`: a durable `SyncLocalStore` backed by sqflite/SQLite.
- Records, outbox and cursors persist across restarts in three generic tables.
- Monotonic-apply guard, per-entity outbox coalescing and keyset pagination,
  matching the in-memory and Drift stores.
- Reactive `watchAll` / `watchRecord` via a manual per-type change notifier
  (sqflite has no native query streams).
