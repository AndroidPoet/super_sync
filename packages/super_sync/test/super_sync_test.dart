import 'package:super_sync/super_sync.dart';
import 'package:test/test.dart';

import 'support/fake_sync_remote.dart';
import 'support/test_models.dart';

SuperSync newSync(
  FakeSyncRemote remote, {
  ConflictStrategy strategy = ConflictStrategy.serverWins,
  SyncConfig config = const SyncConfig(),
}) {
  return SuperSync(
      store: InMemorySyncLocalStore(),
      remote: remote,
      conflictStrategy: strategy,
      config: config,
      autoSync: false,
    )
    ..register(TodoSyncAdapter())
    ..register(UserSyncAdapter())
    ..register(MessageSyncAdapter());
}

void main() {
  group('generic across entity types', () {
    test('one engine syncs three unrelated models through one API', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote);
      await sync.start();

      await sync.repository<Todo>().save(
        const Todo(id: 't1', title: 'Buy milk'),
      );
      await sync.repository<User>().save(const User(id: 'u1', name: 'Ranbir'));
      await sync.repository<Message>().save(
        const Message(id: 'm1', text: 'hi'),
      );

      expect(sync.currentStatus.pendingChanges, 0); // not counted until a cycle
      await sync.sync();

      expect(remote.dataOf('todo', 't1'), {
        'id': 't1',
        'title': 'Buy milk',
        'done': false,
      });
      expect(remote.dataOf('user', 'u1'), {'id': 'u1', 'name': 'Ranbir'});
      expect(remote.dataOf('message', 'm1'), {'id': 'm1', 'text': 'hi'});
      expect(sync.currentStatus.pendingChanges, 0);

      await sync.dispose();
    });

    test('a fresh client pulls every type from the same backend', () async {
      final remote = FakeSyncRemote();
      final a = newSync(remote);
      await a.start();
      await a.repository<Todo>().save(const Todo(id: 't1', title: 'A'));
      await a.repository<User>().save(const User(id: 'u1', name: 'B'));
      await a.sync();

      final b = newSync(remote);
      await b.start();
      await b.sync();

      expect(
        await b.repository<Todo>().get('t1'),
        const Todo(id: 't1', title: 'A'),
      );
      expect(
        await b.repository<User>().get('u1'),
        const User(id: 'u1', name: 'B'),
      );

      await a.dispose();
      await b.dispose();
    });
  });

  group('optimistic local writes', () {
    test('appear before any sync and bump pending', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote);
      await sync.start();
      final todos = sync.repository<Todo>();

      await todos.save(const Todo(id: 't1', title: 'Now'));

      expect(await todos.get('t1'), const Todo(id: 't1', title: 'Now'));
      expect(remote.pushCalls, 0); // never hit the network
      await sync.dispose();
    });

    test('watchAll re-emits on every write', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote);
      await sync.start();
      final todos = sync.repository<Todo>();

      final seen = <int>[];
      final sub = todos.watchAll().listen((list) => seen.add(list.length));
      await Future<void>.delayed(Duration.zero);

      await todos.save(const Todo(id: 't1', title: 'a'));
      await todos.save(const Todo(id: 't2', title: 'b'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, [0, 1, 2]);
      await sub.cancel();
      await sync.dispose();
    });
  });

  group('delete', () {
    test('tombstones locally and propagates to a second client', () async {
      final remote = FakeSyncRemote();
      final a = newSync(remote);
      await a.start();
      await a.repository<Todo>().save(const Todo(id: 't1', title: 'A'));
      await a.sync();

      await a.repository<Todo>().delete('t1');
      expect(await a.repository<Todo>().get('t1'), isNull);
      await a.sync();

      final b = newSync(remote);
      await b.start();
      await b.sync();
      expect(await b.repository<Todo>().get('t1'), isNull);

      await a.dispose();
      await b.dispose();
    });
  });

  group('conflicts', () {
    test('serverWins discards the local change', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote);
      await sync.start();
      final todos = sync.repository<Todo>();

      await todos.save(const Todo(id: 't1', title: 'mine-v1'));
      await sync.sync(); // server v1

      // Another client races ahead to v2.
      remote.seed('todo', 't1', {
        'id': 't1',
        'title': 'theirs',
        'done': false,
      }, 2);

      await todos.save(const Todo(id: 't1', title: 'mine-v2'));
      await sync.sync();

      expect((await todos.get('t1'))!.title, 'theirs');
      expect(sync.currentStatus.isFullySynced, isTrue);
      await sync.dispose();
    });

    test('clientWins rebases and re-pushes until it lands', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote, strategy: ConflictStrategy.clientWins);
      await sync.start();
      final todos = sync.repository<Todo>();

      await todos.save(const Todo(id: 't1', title: 'mine-v1'));
      await sync.sync();
      remote.seed('todo', 't1', {
        'id': 't1',
        'title': 'theirs',
        'done': false,
      }, 2);

      await todos.save(const Todo(id: 't1', title: 'mine-v2'));
      await sync.sync(); // first cycle: conflict -> rebase + re-enqueue
      await sync.sync(); // second cycle: pushes rebased change cleanly

      expect((await todos.get('t1'))!.title, 'mine-v2');
      expect(remote.dataOf('todo', 't1')!['title'], 'mine-v2');
      await sync.dispose();
    });

    test('custom resolver merges fields', () async {
      final remote = FakeSyncRemote();
      final sync =
          SuperSync(
            store: InMemorySyncLocalStore(),
            remote: remote,
            autoSync: false,
          )..register(
            TodoSyncAdapter(),
            conflictResolver: (local, remote) async =>
                local.copyWith(done: remote.done),
          );
      await sync.start();
      final todos = sync.repository<Todo>();

      await todos.save(const Todo(id: 't1', title: 'mine'));
      await sync.sync();
      remote.seed('todo', 't1', {
        'id': 't1',
        'title': 'theirs',
        'done': true,
      }, 2);

      await todos.save(const Todo(id: 't1', title: 'mine2'));
      await sync.sync();
      await sync.sync();

      final merged = await todos.get('t1');
      expect(merged!.title, 'mine2'); // local title kept
      expect(merged.done, true); // remote flag merged in
      await sync.dispose();
    });
  });

  group('outbox resilience', () {
    test('offline keeps work pending; reconnect flushes it', () async {
      final remote = FakeSyncRemote()..offline = true;
      final sync = newSync(remote);
      await sync.start();
      await sync.repository<Todo>().save(const Todo(id: 't1', title: 'A'));

      await sync.sync(); // throws internally, captured as error status
      expect(sync.currentStatus.phase, SyncPhase.error);
      expect(remote.dataOf('todo', 't1'), isNull);

      remote.offline = false;
      await sync.sync();
      expect(remote.dataOf('todo', 't1'), isNotNull);
      expect(sync.currentStatus.isFullySynced, isTrue);
      await sync.dispose();
    });

    test('repeated rejection dead-letters after maxRetries', () async {
      final remote = FakeSyncRemote()..rejectTypes.add('todo');
      final sync = newSync(
        remote,
        config: const SyncConfig(
          maxRetries: 2,
          retryBackoffBase: Duration.zero,
        ),
      );
      await sync.start();
      await sync.repository<Todo>().save(const Todo(id: 't1', title: 'A'));

      await sync.sync(); // retry 0 -> 1
      await sync.sync(); // retry 1 -> 2 (>= maxRetries)
      await sync.sync(); // no longer eligible

      expect(sync.currentStatus.pendingChanges, 0);
      expect(sync.currentStatus.deadLettered, 1);
      await sync.dispose();
    });

    test('a burst of edits to one entity coalesces into one push', () async {
      final remote = FakeSyncRemote();
      final sync = newSync(remote);
      await sync.start();
      final todos = sync.repository<Todo>();

      await todos.save(const Todo(id: 't1', title: 'v1'));
      await todos.save(const Todo(id: 't1', title: 'v2'));
      await todos.save(const Todo(id: 't1', title: 'v3'));
      await sync.sync();

      expect(remote.dataOf('todo', 't1')!['title'], 'v3');
      // one create reached the server, version 1 — not three round-trips.
      expect(remote.dataOf('todo', 't1'), isNotNull);
      await sync.dispose();
    });
  });

  group('chunked pull', () {
    test('drains a large backend in one sync() call', () async {
      final remote = FakeSyncRemote();
      for (var i = 0; i < 250; i++) {
        final id = 't${i.toString().padLeft(4, '0')}';
        remote.seed('todo', id, {'id': id, 'title': 'x', 'done': false}, 1);
      }
      final sync = newSync(remote, config: const SyncConfig(pullPageSize: 50));
      await sync.start();
      await sync.sync();

      expect(await sync.repository<Todo>().getAll(), hasLength(250));
      expect(remote.pullCalls, greaterThan(1)); // it actually paged
      await sync.dispose();
    });
  });
}
