/// The only thing a model must provide to be synced: identity and
/// (de)serialization.
///
/// Everything else — local storage, the outbox, batching, conflict resolution,
/// pagination — is handled generically by the engine. Implement one adapter per
/// model:
///
/// ```dart
/// class TodoSyncAdapter implements SyncEntityAdapter<Todo> {
///   @override
///   String get type => 'todo';
///
///   @override
///   String idOf(Todo value) => value.id;
///
///   @override
///   Map<String, Object?> encode(Todo value) =>
///       {'id': value.id, 'title': value.title, 'done': value.done};
///
///   @override
///   Todo decode(Map<String, Object?> data) => Todo(
///         id: data['id']! as String,
///         title: data['title']! as String,
///         done: data['done']! as bool,
///       );
/// }
/// ```
abstract interface class SyncEntityAdapter<T> {
  /// The stable wire/storage name for this entity type, e.g. `'todo'`. Must be
  /// unique across all registered adapters.
  String get type;

  /// Returns the stable identity of [value].
  String idOf(T value);

  /// Encodes [value] into a JSON-compatible map.
  Map<String, Object?> encode(T value);

  /// Reconstructs a [T] from a previously [encode]d map.
  T decode(Map<String, Object?> data);
}
