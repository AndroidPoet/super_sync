import 'package:meta/meta.dart';

/// A comparison operator in a [SyncCondition].
enum SyncFilterOp {
  /// `=`
  eq,

  /// `<>`
  ne,

  /// `>`
  gt,

  /// `>=`
  gte,

  /// `<`
  lt,

  /// `<=`
  lte,

  /// `IN (...)`
  inList,

  /// `LIKE`
  like,

  /// `IS NULL`
  isNull,

  /// `IS NOT NULL`
  notNull,
}

/// A single field filter, e.g. `done == false`.
@immutable
class SyncCondition {
  /// Creates a condition on [field] using [op] and [value].
  const SyncCondition(this.field, this.op, this.value);

  /// The field name (the key inside the JSON blob).
  final String field;

  /// The comparison operator.
  final SyncFilterOp op;

  /// The right-hand value (`null` for [SyncFilterOp.isNull] / `notNull`).
  final Object? value;
}

/// An ordering clause, e.g. `priority DESC`.
@immutable
class SyncOrder {
  /// Creates an ordering on [field].
  const SyncOrder(this.field, {this.descending = false});

  /// The field name to sort by.
  final String field;

  /// Whether to sort descending.
  final bool descending;
}

/// A declarative query: conditions, ordering and an optional limit.
///
/// Stores read [fields] to know which columns to materialize (lazily projecting
/// them out of the JSON blob on first use).
@immutable
class SyncQuerySpec {
  /// Creates a spec.
  const SyncQuerySpec({
    this.conditions = const [],
    this.orders = const [],
    this.limit,
  });

  /// The AND-combined filters.
  final List<SyncCondition> conditions;

  /// The ordering clauses, applied in order.
  final List<SyncOrder> orders;

  /// The maximum number of rows to return, or `null` for all.
  final int? limit;

  /// Every field referenced by a condition or ordering.
  Set<String> get fields => {
    for (final c in conditions) c.field,
    for (final o in orders) o.field,
  };

  /// Returns a copy with the given parts replaced.
  SyncQuerySpec copyWith({
    List<SyncCondition>? conditions,
    List<SyncOrder>? orders,
    int? limit,
  }) => SyncQuerySpec(
    conditions: conditions ?? this.conditions,
    orders: orders ?? this.orders,
    limit: limit ?? this.limit,
  );
}

/// A chainable, type-safe query over a collection.
///
/// Build it from `repository.query()` / `repository.where(...)`, chain filters
/// and ordering, then call [get]. Fields referenced here are materialized into
/// indexed columns on first use — no schema declaration required.
///
/// ```dart
/// await todos
///     .where('done', isEqualTo: false)
///     .orderBy('priority', descending: true)
///     .limit(20)
///     .get();
/// ```
@immutable
class SyncQuery<T> {
  /// Creates a query that runs [_run] against the accumulated [spec].
  const SyncQuery(this._run, [this.spec = const SyncQuerySpec()]);

  final Future<List<T>> Function(SyncQuerySpec spec) _run;

  /// The spec accumulated so far.
  final SyncQuerySpec spec;

  SyncQuery<T> _with(SyncQuerySpec next) => SyncQuery<T>(_run, next);

  /// Adds an AND filter on [field]. Provide exactly one comparator.
  SyncQuery<T> where(
    String field, {
    Object? isEqualTo,
    Object? notEqualTo,
    Object? greaterThan,
    Object? greaterThanOrEqualTo,
    Object? lessThan,
    Object? lessThanOrEqualTo,
    bool? isNull,
    List<Object?>? whereIn,
    String? like,
  }) {
    final SyncCondition condition;
    if (isEqualTo != null) {
      condition = SyncCondition(field, SyncFilterOp.eq, isEqualTo);
    } else if (notEqualTo != null) {
      condition = SyncCondition(field, SyncFilterOp.ne, notEqualTo);
    } else if (greaterThan != null) {
      condition = SyncCondition(field, SyncFilterOp.gt, greaterThan);
    } else if (greaterThanOrEqualTo != null) {
      condition = SyncCondition(field, SyncFilterOp.gte, greaterThanOrEqualTo);
    } else if (lessThan != null) {
      condition = SyncCondition(field, SyncFilterOp.lt, lessThan);
    } else if (lessThanOrEqualTo != null) {
      condition = SyncCondition(field, SyncFilterOp.lte, lessThanOrEqualTo);
    } else if (whereIn != null) {
      condition = SyncCondition(field, SyncFilterOp.inList, whereIn);
    } else if (like != null) {
      condition = SyncCondition(field, SyncFilterOp.like, like);
    } else if (isNull != null) {
      condition = SyncCondition(
        field,
        isNull ? SyncFilterOp.isNull : SyncFilterOp.notNull,
        null,
      );
    } else {
      throw ArgumentError('where("$field") needs a comparator.');
    }
    return _with(
      spec.copyWith(conditions: [...spec.conditions, condition]),
    );
  }

  /// Adds an ordering on [field].
  SyncQuery<T> orderBy(String field, {bool descending = false}) => _with(
    spec.copyWith(
      orders: [
        ...spec.orders,
        SyncOrder(field, descending: descending),
      ],
    ),
  );

  /// Caps the result at [count] rows.
  SyncQuery<T> limit(int count) => _with(spec.copyWith(limit: count));

  /// Runs the query and returns the matching models.
  Future<List<T>> get() => _run(spec);
}
