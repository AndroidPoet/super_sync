# Changelog

## 0.1.0

Initial release.

- `DriftSyncLocalStore` — a durable, SQLite-backed `SyncLocalStore` for
  super_sync, built on Drift.
- Persists records, the outbox and sync cursors across restarts.
- Behaviourally identical to the in-memory store: monotonic-apply guard,
  per-entity outbox coalescing and keyset pagination.
- Reactivity rides Drift's own query streams — `watchAll` / `watchRecord`
  re-emit on every relevant change with no manual notification.
