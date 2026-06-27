/// The kind of change a local mutation represents.
enum SyncOperation {
  /// The entity was created locally and has never reached the server.
  create,

  /// An existing entity's fields changed.
  update,

  /// The entity was deleted locally (kept as a tombstone until acknowledged).
  delete,
}
