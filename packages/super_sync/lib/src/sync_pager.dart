import 'dart:async';

import 'package:meta/meta.dart';
import 'package:super_sync/src/sync_local_store.dart';
import 'package:super_sync/src/sync_record.dart';

/// One reactive snapshot of a paginated list.
@immutable
class SyncPage<T> {
  /// Creates a page snapshot.
  const SyncPage({
    required this.items,
    required this.hasMore,
    this.isLoading = false,
  });

  /// The items loaded so far (the accumulated window, not just the last page).
  final List<T> items;

  /// Whether more items exist beyond [items].
  final bool hasMore;

  /// Whether a [SyncPager.loadMore] / [SyncPager.refresh] is in flight.
  final bool isLoading;
}

/// A smooth, infinite-scroll-friendly window over a synced entity type.
///
/// Backed by **keyset** reads, so loading the 100th page costs the same as the
/// first. The window is **reactive**: optimistic local writes and incoming
/// server changes re-emit the visible items instantly, with no manual refresh.
/// One [pages] stream feeds a `ListView`; call [loadMore] at the bottom.
///
/// ```dart
/// final pager = todos.paged(pageSize: 30);
/// pager.pages.listen((page) => render(page.items, more: page.hasMore));
/// // on scroll-to-end:
/// await pager.loadMore();
/// ```
class SyncPager<T> {
  /// Creates a pager. Usually obtained via `repository.paged()`.
  SyncPager({
    required SyncLocalStore store,
    required String type,
    required T Function(Map<String, Object?> data) decode,
    int pageSize = 30,
    Future<void> Function()? ensureStarted,
  }) : _store = store,
       _type = type,
       _decode = decode,
       _pageSize = pageSize,
       _ensureStarted = ensureStarted,
       _window = pageSize {
    _out = StreamController<SyncPage<T>>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final SyncLocalStore _store;
  final String _type;
  final T Function(Map<String, Object?> data) _decode;
  final int _pageSize;
  final Future<void> Function()? _ensureStarted;

  int _window;
  late final StreamController<SyncPage<T>> _out;
  StreamSubscription<List<SyncRecord>>? _sub;
  SyncPage<T> _last = SyncPage<T>(
    items: const [],
    hasMore: false,
    isLoading: true,
  );

  /// The reactive stream of page snapshots (broadcast; replays the latest).
  Stream<SyncPage<T>> get pages async* {
    yield _last;
    yield* _out.stream;
  }

  /// The most recent snapshot.
  SyncPage<T> get value => _last;

  void _start() {
    unawaited(_bind());
  }

  Future<void> _bind() async {
    final ensure = _ensureStarted;
    if (ensure != null) await ensure();
    _sub ??= _store.watchAll(_type).listen((_) => unawaited(_recompute()));
  }

  void _stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  Future<void> _recompute({bool loading = false}) async {
    if (loading) _push(_last.items, _last.hasMore, isLoading: true);
    final page = await _store.readPage(_type, limit: _window);
    _push(
      page.records.map((r) => _decode(r.data)).toList(),
      page.hasMore,
    );
  }

  void _push(List<T> items, bool hasMore, {bool isLoading = false}) {
    _last = SyncPage<T>(items: items, hasMore: hasMore, isLoading: isLoading);
    if (!_out.isClosed) _out.add(_last);
  }

  /// Grows the window by one page and re-emits.
  Future<void> loadMore() async {
    if (!_last.hasMore) return;
    _window += _pageSize;
    await _recompute(loading: true);
  }

  /// Collapses the window back to the first page.
  Future<void> refresh() async {
    _window = _pageSize;
    await _recompute(loading: true);
  }

  /// Stops listening and releases the stream.
  Future<void> dispose() async {
    _stop();
    await _out.close();
  }
}
