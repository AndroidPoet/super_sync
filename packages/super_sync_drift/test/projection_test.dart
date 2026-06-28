import 'dart:io';

import 'package:drift/native.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_drift/super_sync_drift.dart';
import 'package:test/test.dart';

class _Todo {
  const _Todo({
    required this.id,
    required this.title,
    this.done = false,
    this.priority = 0,
  });

  factory _Todo.fromJson(Map<String, Object?> j) => _Todo(
    id: j['id']! as String,
    title: j['title']! as String,
    done: (j['done'] as bool?) ?? false,
    priority: (j['priority'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String title;
  final bool done;
  final int priority;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    'priority': priority,
  };
}

class _AcceptRemote implements SyncRemote {
  @override
  Future<PushResponse> push(List<SyncMutation> mutations) async =>
      PushResponse([
        for (final m in mutations)
          MutationResult(
            mutationId: m.id,
            status: MutationStatus.applied,
            serverVersion: 1,
          ),
      ]);

  @override
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  }) async => const PullResponse(changes: []);
}

SyncRecord _rec(String id, Map<String, Object?> data) =>
    SyncRecord(type: 'todo', id: id, data: data, updatedAt: DateTime.now());

void main() {
  group('typed projection queries', () {
    test('query by an indexed field, ordered', () async {
      final store = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase.memory()),
      );
      await store.initialize();
      await store.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [
            SyncField.boolean('done', indexed: true),
            SyncField.integer('priority', indexed: true),
          ],
        ),
      ]);

      await store.putRecord(
        _rec('a', {'id': 'a', 'title': 'A', 'done': false, 'priority': 2}),
      );
      await store.putRecord(
        _rec('b', {'id': 'b', 'title': 'B', 'done': true, 'priority': 9}),
      );
      await store.putRecord(
        _rec('c', {'id': 'c', 'title': 'C', 'done': false, 'priority': 5}),
      );

      final open = await store.queryProjection(
        'todo',
        const SyncQuerySpec(
          conditions: [SyncCondition('done', SyncFilterOp.eq, false)],
          orders: [SyncOrder('priority', descending: true)],
        ),
      );
      expect(open.map((r) => r.id), ['c', 'a']);

      await store.close();
    });

    test(
      'end-to-end through SuperSync.collection(fields:) + query()',
      () async {
        final db = SuperSync(
          store: DriftSyncLocalStore(
            SuperSyncDatabase(NativeDatabase.memory()),
          ),
          remote: _AcceptRemote(),
          autoSync: false,
        );
        final todos = db.collection<_Todo>(
          type: 'todo',
          id: (t) => t.id,
          toJson: (t) => t.toJson(),
          fromJson: _Todo.fromJson,
          fields: const [
            SyncField.boolean('done', indexed: true),
            SyncField.integer('priority'),
          ],
        );

        await todos.save(const _Todo(id: 'a', title: 'A', priority: 1));
        await todos.save(
          const _Todo(id: 'b', title: 'B', done: true, priority: 3),
        );

        final pending = await todos.where('done', isEqualTo: false).get();
        expect(pending.map((t) => t.id), ['a']);
        await db.dispose();
      },
    );

    test('deletes drop out of the projected table', () async {
      final store = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase.memory()),
      );
      await store.initialize();
      await store.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [SyncField.boolean('done')],
        ),
      ]);
      await store.putRecord(
        _rec('a', {'id': 'a', 'title': 'A', 'done': false}),
      );
      const onlyDone = SyncQuerySpec(
        conditions: [SyncCondition('done', SyncFilterOp.notNull, null)],
      );
      expect(await store.queryProjection('todo', onlyDone), hasLength(1));

      await store.putRecord(
        _rec('a', {
          'id': 'a',
          'title': 'A',
          'done': false,
        }).copyWith(deleted: true, localVersion: 2),
      );
      expect(await store.queryProjection('todo', onlyDone), isEmpty);
      await store.close();
    });
  });

  group('lazy materialization (no schema, no migration)', () {
    test('a never-declared field auto-projects from existing blobs', () async {
      final store = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase.memory()),
      );
      await store.initialize();
      // No configureProjections at all. Write data first...
      await store.putRecord(
        _rec('a', {'id': 'a', 'title': 'A', 'done': false, 'priority': 7}),
      );
      await store.putRecord(
        _rec('b', {'id': 'b', 'title': 'B', 'done': true, 'priority': 2}),
      );
      // ...then query a field for the very first time: it materializes +
      // backfills from the blob on demand.
      final hits = await store.queryProjection(
        'todo',
        const SyncQuerySpec(
          conditions: [SyncCondition('priority', SyncFilterOp.gte, 5)],
        ),
      );
      expect(hits.single.id, 'a');
      await store.close();
    });

    test(
      'materialized fields persist across reopen; new fields add lazily',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'supersync_proj_lazy',
        );
        final file = File('${dir.path}/db.sqlite');

        final first = DriftSyncLocalStore(
          SuperSyncDatabase(NativeDatabase(file)),
        );
        await first.initialize();
        await first.putRecord(
          _rec('a', {'id': 'a', 'title': 'A', 'done': false, 'priority': 7}),
        );
        // Materialize `done` by querying it.
        await first.queryProjection(
          'todo',
          const SyncQuerySpec(
            conditions: [SyncCondition('done', SyncFilterOp.eq, false)],
          ),
        );
        await first.close();

        // Reopen: `done` is remembered (proj_meta). A brand-new field `priority`
        // materializes on first query — no migration written.
        final second = DriftSyncLocalStore(
          SuperSyncDatabase(NativeDatabase(file)),
        );
        await second.initialize();
        final byPriority = await second.queryProjection(
          'todo',
          const SyncQuerySpec(
            conditions: [SyncCondition('priority', SyncFilterOp.eq, 7)],
          ),
        );
        expect(byPriority.single.id, 'a');
        await second.close();
        await dir.delete(recursive: true);
      },
    );

    test(
      'mixed value types compare correctly (SQLite dynamic typing)',
      () async {
        final store = DriftSyncLocalStore(
          SuperSyncDatabase(NativeDatabase.memory()),
        );
        await store.initialize();
        await store.putRecord(_rec('a', {'id': 'a', 'score': 10}));
        await store.putRecord(_rec('a2', {'id': 'a2', 'score': 3.5}));
        final hi = await store.queryProjection(
          'todo',
          const SyncQuerySpec(
            conditions: [SyncCondition('score', SyncFilterOp.gt, 5)],
          ),
        );
        expect(hi.single.id, 'a');
        await store.close();
      },
    );
  });
}
