# Changelog

## 0.1.0

Initial release — the pure-Dart core engine.

- Generic, model-agnostic sync: register any model via a `SyncEntityAdapter<T>`
  and use it through a typed `SyncRepository<T>`.
- Backend-agnostic: a backend is one `SyncRemote` implementation away (push +
  pull). No vendor lock-in.
- Offline-first: optimistic local writes through an outbox; reads are instant.
- Built to scale:
  - keyset pagination (`SyncPager<T>`) — deep pages stay O(page size);
  - chunked pull drains a large backend across pages in one cycle;
  - paged push drains the outbox in bounded batches;
  - per-entity outbox coalescing collapses edit bursts into one push;
  - exponential backoff with a dead-letter ceiling;
  - monotonic-apply guard prevents out-of-order regressions.
- Version-based conflict detection with `serverWins` / `clientWins` defaults and
  per-entity custom resolvers.
- `InMemorySyncLocalStore` ships in the box (the reference store implementation).
- Live `SyncStatus` stream (phase, pending, dead-lettered, last-synced).
- Tombstone garbage collection.
