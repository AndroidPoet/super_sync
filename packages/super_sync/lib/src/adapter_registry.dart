import 'package:meta/meta.dart';
import 'package:super_sync/src/sync_conflict.dart';
import 'package:super_sync/src/sync_entity_adapter.dart';

/// A type-erased view of a registered adapter, so the engine can encode,
/// decode, identify and resolve conflicts on records without statically knowing
/// the model type `T`.
@internal
class RegisteredEntity {
  RegisteredEntity._({
    required this.type,
    required this.encode,
    required this.decode,
    required this.idOf,
    required this.resolveData,
  });

  /// Creates a registration from a typed [adapter] and optional [resolver],
  /// capturing them behind `Object?`-typed closures.
  static RegisteredEntity from<T>(
    SyncEntityAdapter<T> adapter, {
    ConflictResolver<T>? resolver,
  }) {
    return RegisteredEntity._(
      type: adapter.type,
      encode: (value) => adapter.encode(value as T),
      idOf: (value) => adapter.idOf(value as T),
      decode: adapter.decode,
      resolveData: resolver == null
          ? null
          : (local, remote) async {
              final winner = await resolver(
                adapter.decode(local),
                adapter.decode(remote),
              );
              return adapter.encode(winner);
            },
    );
  }

  /// The entity type name.
  final String type;

  /// Encodes a model (passed as `Object?`) to a data map.
  final Map<String, Object?> Function(Object? value) encode;

  /// Decodes a data map back to a model.
  final Object? Function(Map<String, Object?> data) decode;

  /// Extracts the id from a model (passed as `Object?`).
  final String Function(Object? value) idOf;

  /// Resolves a conflict on raw data maps, or `null` to fall back to the global
  /// [ConflictStrategy].
  final Future<Map<String, Object?>> Function(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  )?
  resolveData;
}

/// Holds every [RegisteredEntity] keyed by its type name and by `Type`.
@internal
class AdapterRegistry {
  final Map<String, RegisteredEntity> _byName = {};
  final Map<Type, RegisteredEntity> _byType = {};

  /// Registers [adapter] (with optional [resolver]). Throws [StateError] on a
  /// duplicate type name.
  void register<T>(
    SyncEntityAdapter<T> adapter, {
    ConflictResolver<T>? resolver,
  }) {
    if (_byName.containsKey(adapter.type)) {
      throw StateError(
        'An adapter for type "${adapter.type}" is already '
        'registered.',
      );
    }
    final entity = RegisteredEntity.from<T>(adapter, resolver: resolver);
    _byName[adapter.type] = entity;
    _byType[T] = entity;
  }

  /// The registration for type name [name], or `null`.
  RegisteredEntity? byName(String name) => _byName[name];

  /// The registration for model type [T].
  RegisteredEntity byType<T>() {
    final e = _byType[T];
    if (e == null) {
      throw StateError(
        'No adapter registered for type $T. Call '
        'SuperSync.register<$T>(...) before using it.',
      );
    }
    return e;
  }

  /// Every registered type name.
  Set<String> get typeNames => _byName.keys.toSet();
}
