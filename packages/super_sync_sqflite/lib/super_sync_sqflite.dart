/// A durable [SyncLocalStore] for super_sync backed by sqflite (SQLite).
///
/// Works with `package:sqflite` on devices and `sqflite_common_ffi` on
/// desktop and in tests. Because sqflite has no reactive query streams, this
/// store provides reactivity through a manual per-type change notifier.
library;

export 'src/sqflite_sync_local_store.dart';
