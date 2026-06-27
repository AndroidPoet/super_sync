# Changelog

## 0.1.0

Initial release.

- `generateFromOpenApi(source)` — turns an OpenAPI 3 document into super_sync
  Dart source: an immutable model and a `SyncEntityAdapter` per schema, a single
  `registerSuperSyncModels(sync)` wiring call, and an `AppSync` facade exposing a
  typed `SyncRepository` per model.
- `super_sync_gen` CLI for one-shot generation.
- No database schema is generated: super_sync stores every model in one generic
  JSON-backed table, so adding or changing a model never migrates the DB.
