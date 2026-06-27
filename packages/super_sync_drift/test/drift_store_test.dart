import 'dart:io';

import 'package:drift/native.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_drift/super_sync_drift.dart';
import 'package:test/test.dart';

class _Note {
  const _Note(this.id, this.text);
  final String id;
  final String text;
}

class _NoteAdapter implements SyncEntityAdapter<_Note> {
  @override
  String get type => 'note';
  @override
  String idOf(_Note v) => v.id;
  @override
  Map<String, Object?> encode(_Note v) => {'id': v.id, 'text': v.text};
  @override
  _Note decode(Map<String, Object?> d) =>
      _Note(d['id']! as String, d['text']! as String);
}

/// An accept-everything remote, enough to prove the engine drives the Drift
/// store end to end.
class _AcceptRemote implements SyncRemote {
  final Map<String, Map<String, Object?>> store = {};
  @override
  Future<PushResponse> push(List<SyncMutation> mutations) async {
    return PushResponse([
      for (final m in mutations)
        MutationResult(
          mutationId: m.id,
          status: MutationStatus.applied,
          serverVersion: 1,
        ),
    ]);
  }

  @override
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  }) async => const PullResponse(changes: []);
}

DriftSyncLocalStore memStore() =>
    DriftSyncLocalStore(SuperSyncDatabase(NativeDatabase.memory()));

void main() {
  group('DriftSyncLocalStore contract', () {
    test('put / read / monotonic guard', () async {
      final store = memStore();
      await store.initialize();

      final v1 = SyncRecord(
        type: 'note',
        id: 'n1',
        data: const {'id': 'n1', 'text': 'a'},
        updatedAt: DateTime.now(),
      );
      await store.putRecord(v1);
      expect((await store.readRecord('note', 'n1'))!.data['text'], 'a');

      // Stale write (lower version) is ignored.
      final stale = v1.copyWith(data: {'id': 'n1', 'text': 'old'});
      await store.putRecord(stale);
      expect((await store.readRecord('note', 'n1'))!.data['text'], 'a');

      // Newer version applies.
      final v2 = v1.copyWith(data: {'id': 'n1', 'text': 'b'}, localVersion: 2);
      await store.putRecord(v2);
      expect((await store.readRecord('note', 'n1'))!.data['text'], 'b');

      await store.close();
    });

    test('keyset pagination', () async {
      final store = memStore();
      await store.initialize();
      for (var i = 0; i < 25; i++) {
        final id = 'n${i.toString().padLeft(3, '0')}';
        await store.putRecord(
          SyncRecord(
            type: 'note',
            id: id,
            data: {'id': id, 'text': 'x'},
            updatedAt: DateTime.now(),
          ),
        );
      }
      final p1 = await store.readPage('note', limit: 10);
      expect(p1.records, hasLength(10));
      expect(p1.hasMore, isTrue);
      final p2 = await store.readPage(
        'note',
        after: p1.nextPageToken,
        limit: 10,
      );
      expect(p2.records.first.id, 'n010');
      expect(await store.count('note'), 25);
      await store.close();
    });

    test('watchAll re-emits on write', () async {
      final store = memStore();
      await store.initialize();
      final seen = <int>[];
      final sub = store
          .watchAll('note')
          .listen((rows) => seen.add(rows.length));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.putRecord(
        SyncRecord(
          type: 'note',
          id: 'n1',
          data: const {'id': 'n1', 'text': 'a'},
          updatedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen.last, 1);
      await sub.cancel();
      await store.close();
    });
  });

  test('engine round-trips over the Drift store', () async {
    final sync = SuperSync(
      store: memStore(),
      remote: _AcceptRemote(),
      autoSync: false,
    )..register(_NoteAdapter());
    await sync.start();
    final notes = sync.repository<_Note>();

    await notes.save(const _Note('n1', 'hello'));
    expect((await notes.get('n1'))!.text, 'hello');
    await sync.sync();
    expect(sync.currentStatus.isFullySynced, isTrue);
    await sync.dispose();
  });

  test('data persists across reopen (real local DB)', () async {
    final dir = await Directory.systemTemp.createTemp('supersync_drift');
    final file = File('${dir.path}/db.sqlite');

    final first = DriftSyncLocalStore(SuperSyncDatabase(NativeDatabase(file)));
    await first.initialize();
    await first.putRecord(
      SyncRecord(
        type: 'note',
        id: 'persist',
        data: const {'id': 'persist', 'text': 'survives restart'},
        updatedAt: DateTime.now(),
      ),
    );
    await first.close();

    // Reopen the same file in a fresh store — data should still be there.
    final second = DriftSyncLocalStore(SuperSyncDatabase(NativeDatabase(file)));
    await second.initialize();
    final row = await second.readRecord('note', 'persist');
    expect(row, isNotNull);
    expect(row!.data['text'], 'survives restart');
    await second.close();

    await dir.delete(recursive: true);
  });
}
