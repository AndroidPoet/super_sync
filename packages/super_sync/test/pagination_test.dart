import 'package:super_sync/super_sync.dart';
import 'package:test/test.dart';

import 'support/fake_sync_remote.dart';
import 'support/test_models.dart';

void main() {
  late FakeSyncRemote remote;
  late SuperSync sync;
  late SyncRepository<Todo> todos;

  setUp(() async {
    remote = FakeSyncRemote();
    sync = SuperSync(
      store: InMemorySyncLocalStore(),
      remote: remote,
      autoSync: false,
    )..register(TodoSyncAdapter());
    await sync.start();
    todos = sync.repository<Todo>();
  });

  tearDown(() => sync.dispose());

  Future<void> seedLocal(int n) async {
    for (var i = 0; i < n; i++) {
      final id = 't${i.toString().padLeft(4, '0')}';
      await todos.save(Todo(id: id, title: 'item $i'));
    }
  }

  test('loadMore walks the window page by page (keyset)', () async {
    await seedLocal(95);
    final pager = todos.paged(pageSize: 30);

    final pages = <SyncPage<Todo>>[];
    final sub = pager.pages.listen(pages.add);
    await Future<void>.delayed(Duration.zero);
    expect(pages.last.items, hasLength(30));
    expect(pages.last.hasMore, isTrue);
    expect(pages.last.items.first.id, 't0000'); // ordered

    await pager.loadMore();
    expect(pager.value.items, hasLength(60));
    await pager.loadMore();
    expect(pager.value.items, hasLength(90));
    await pager.loadMore();
    expect(pager.value.items, hasLength(95));
    expect(pager.value.hasMore, isFalse);

    await sub.cancel();
    await pager.dispose();
  });

  test('window re-emits live when an item is added', () async {
    await seedLocal(3);
    final pager = todos.paged(pageSize: 30);
    final lengths = <int>[];
    final sub = pager.pages.listen((p) => lengths.add(p.items.length));
    await Future<void>.delayed(Duration.zero);

    await todos.save(const Todo(id: 't0003', title: 'new'));
    await Future<void>.delayed(Duration.zero);

    expect(lengths.last, 4); // optimistic insert shows with no manual refresh
    await sub.cancel();
    await pager.dispose();
  });

  test('deleting an item shrinks the live window', () async {
    await seedLocal(3);
    final pager = todos.paged(pageSize: 30);
    final sub = pager.pages.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    await todos.delete('t0001');
    await Future<void>.delayed(Duration.zero);

    expect(pager.value.items.map((t) => t.id), ['t0000', 't0002']);
    await sub.cancel();
    await pager.dispose();
  });
}
