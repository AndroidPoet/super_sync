import 'package:meta/meta.dart';

/// The storage type of a [SyncField] projected out of the JSON blob.
enum SyncFieldType {
  /// A text column (`TEXT`).
  text,

  /// A whole-number column (`INTEGER`).
  integer,

  /// A floating-point column (`REAL`).
  real,

  /// A boolean column (stored as `INTEGER` `0`/`1`).
  boolean,
}

/// One field lifted from a model's JSON into a typed, indexable column.
///
/// The JSON blob stays the source of truth; a [SyncField] just declares that a
/// value inside it should *also* live in a real column so you can run indexed
/// `WHERE` / `ORDER BY` queries. Because the column is derived, changing the set
/// of fields never needs a hand-written migration — the projection is rebuilt
/// from the blob.
@immutable
class SyncField {
  /// Creates a field named [name] of [type]. [jsonKey] defaults to [name].
  const SyncField(
    this.name,
    this.type, {
    this.indexed = false,
    this.nullable = true,
    String? jsonKey,
  }) : jsonKey = jsonKey ?? name;

  /// A `TEXT` field.
  const SyncField.text(
    String name, {
    bool indexed = false,
    bool nullable = true,
    String? jsonKey,
  }) : this(
         name,
         SyncFieldType.text,
         indexed: indexed,
         nullable: nullable,
         jsonKey: jsonKey,
       );

  /// An `INTEGER` field.
  const SyncField.integer(
    String name, {
    bool indexed = false,
    bool nullable = true,
    String? jsonKey,
  }) : this(
         name,
         SyncFieldType.integer,
         indexed: indexed,
         nullable: nullable,
         jsonKey: jsonKey,
       );

  /// A `REAL` field.
  const SyncField.real(
    String name, {
    bool indexed = false,
    bool nullable = true,
    String? jsonKey,
  }) : this(
         name,
         SyncFieldType.real,
         indexed: indexed,
         nullable: nullable,
         jsonKey: jsonKey,
       );

  /// A boolean field (stored `0`/`1`).
  const SyncField.boolean(
    String name, {
    bool indexed = false,
    bool nullable = true,
    String? jsonKey,
  }) : this(
         name,
         SyncFieldType.boolean,
         indexed: indexed,
         nullable: nullable,
         jsonKey: jsonKey,
       );

  /// The column name.
  final String name;

  /// The key to read inside the JSON blob (defaults to [name]).
  final String jsonKey;

  /// The column's storage type.
  final SyncFieldType type;

  /// Whether to create an index on this column for fast lookups/sorting.
  final bool indexed;

  /// Whether the value may be null (advisory; not enforced at the DB level yet).
  final bool nullable;
}

/// The typed, queryable read-model for one entity [type] — the set of fields a
/// store should project out of the JSON blob into real columns.
@immutable
class SyncProjection {
  /// Creates a projection for [type] over [fields].
  const SyncProjection({required this.type, required this.fields});

  /// The entity type this projection covers.
  final String type;

  /// The fields to project into columns.
  final List<SyncField> fields;
}
