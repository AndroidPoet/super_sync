<h1 align="center">super_sync_codegen</h1>

<p align="center">
Point it at an OpenAPI schema; get a complete
<a href="https://pub.dev/packages/super_sync">super_sync</a> data layer.
</p>

---

For every schema in your OpenAPI 3 spec, this generates:

- an **immutable model** class,
- a **`SyncEntityAdapter`** (identity + encode/decode),
- a single **`registerSuperSyncModels(sync)`** call that wires them all,
- an **`AppSync`** facade exposing a typed `SyncRepository` per model.

So your whole offline-first data layer is one generated file — and because
super_sync stores everything in one generic JSON-backed table, **no database
schema or migration is ever generated**. Add a field to the spec, re-generate,
done.

## Generate

```sh
dart run super_sync_codegen:super_sync_gen openapi.yaml lib/app_models.g.dart
```

## Use the generated API

```dart
final sync = SuperSync(store: DriftSyncLocalStore(db), remote: MyRemote());
registerSuperSyncModels(sync);     // one generated call wires every model
await sync.start();

final app = AppSync(sync);         // one generated typed entry point
await app.todos.save(const Todo(id: 't1', title: 'Buy milk', completed: false));
app.users.watchAll();
```

## Input

Any OpenAPI 3 document with `components/schemas`. A schema is generated when it
has an `id` property (the sync identity). Types map as:

| OpenAPI | Dart |
| --- | --- |
| `string` | `String` |
| `integer` | `int` |
| `number` | `double` |
| `boolean` | `bool` |
| `array` | `List<T>` |
| `object` / `$ref` | `Map<String, Object?>` |

Properties not in `required` become nullable. `snake_case` keys become
`camelCase` Dart fields (the wire key is preserved).

## License

Apache-2.0 © androidpoet (Ranbir Singh)
