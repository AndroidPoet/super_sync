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
        where: 'done = ?',
        whereArgs: [0],
        orderBy: 'priority DESC',
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

        final pending = await todos.query(where: 'done = ?', args: [0]);
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
      expect(await store.queryProjection('todo'), hasLength(1));

      await store.putRecord(
        _rec('a', {
          'id': 'a',
          'title': 'A',
          'done': false,
        }).copyWith(deleted: true, localVersion: 2),
      );
      expect(await store.queryProjection('todo'), isEmpty);
      await store.close();
    });
  });

  group('automatic migration (no hand-written migration)', () {
    test('additive: a new field backfills from the blob on reopen', () async {
      final dir = await Directory.systemTemp.createTemp('supersync_proj_add');
      final file = File('${dir.path}/db.sqlite');

      // v1 of the model projects only `done`.
      final first = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase(file)),
      );
      await first.initialize();
      await first.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [SyncField.boolean('done')],
        ),
      ]);
      await first.putRecord(
        _rec('a', {'id': 'a', 'title': 'A', 'done': false, 'priority': 7}),
      );
      await first.close();

      // v2 adds `priority`. No migration written; it backfills from the blob.
      final second = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase(file)),
      );
      await second.initialize();
      await second.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [
            SyncField.boolean('done'),
            SyncField.integer('priority'),
          ],
        ),
      ]);
      final hits = await second.queryProjection(
        'todo',
        where: 'priority = ?',
        whereArgs: [7],
      );
      expect(hits.single.id, 'a');
      await second.close();
      await dir.delete(recursive: true);
    });

    test('incompatible: dropping a field rebuilds from the blob', () async {
      final dir = await Directory.systemTemp.createTemp('supersync_proj_drop');
      final file = File('${dir.path}/db.sqlite');

      final first = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase(file)),
      );
      await first.initialize();
      await first.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [
            SyncField.boolean('done'),
            SyncField.integer('priority'),
          ],
        ),
      ]);
      await first.putRecord(
        _rec('a', {'id': 'a', 'title': 'A', 'done': true, 'priority': 4}),
      );
      await first.close();

      // v2 removes `priority` -> incompatible -> table rebuilt from the blob.
      final second = DriftSyncLocalStore(
        SuperSyncDatabase(NativeDatabase(file)),
      );
      await second.initialize();
      await second.configureProjections([
        const SyncProjection(
          type: 'todo',
          fields: [SyncField.boolean('done')],
        ),
      ]);
      final done = await second.queryProjection(
        'todo',
        where: 'done = ?',
        whereArgs: [1],
      );
      expect(done.single.id, 'a');
      // Querying the dropped column must now fail (it's gone from the table).
      await expectLater(
        second.queryProjection('todo', where: 'priority = ?', whereArgs: [4]),
        throwsA(anything),
      );
      await second.close();
      await dir.delete(recursive: true);
    });
  });
}
