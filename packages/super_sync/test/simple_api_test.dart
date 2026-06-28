import 'package:super_sync/super_sync.dart';
import 'package:test/test.dart';

import 'support/fake_sync_remote.dart';

/// A plain model with ordinary toJson/fromJson — no adapter class, no mixins.
class Note {
  const Note({required this.id, required this.text});

  factory Note.fromJson(Map<String, Object?> j) =>
      Note(id: j['id']! as String, text: j['text']! as String);

  final String id;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'text': text};
}

void main() {
  group('the simple API hides the local DB', () {
    test('no adapter class, no register, no start — it just works', () async {
      final db = SuperSync(
        store: InMemorySyncLocalStore(),
        remote: FakeSyncRemote(),
        autoSync: false,
      );

      // One call declares the collection. We never call start().
      final notes = db.collection<Note>(
        id: (n) => n.id,
        toJson: (n) => n.toJson(),
        fromJson: Note.fromJson,
        type: 'note',
      );

      // Reads/writes feel like a normal client.
      await notes.save(const Note(id: 'n1', text: 'hello'));
      expect((await notes.get('n1'))!.text, 'hello');

      final all = await notes.all();
      expect(all, hasLength(1));

      await notes.remove('n1');
      expect(await notes.get('n1'), isNull);

      await db.dispose();
    });

    test('stream() emits without any explicit start()', () async {
      final db = SuperSync(
        store: InMemorySyncLocalStore(),
        remote: FakeSyncRemote(),
        autoSync: false,
      );
      final notes = db.collection<Note>(
        id: (n) => n.id,
        toJson: (n) => n.toJson(),
        fromJson: Note.fromJson,
        type: 'note',
      );

      final seen = <int>[];
      final sub = notes.stream().listen((rows) => seen.add(rows.length));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await notes.save(const Note(id: 'n1', text: 'a'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(seen.last, 1);
      await sub.cancel();
      await db.dispose();
    });

    test('calling collection<T>() twice returns the same repository', () async {
      final db = SuperSync(
        store: InMemorySyncLocalStore(),
        remote: FakeSyncRemote(),
        autoSync: false,
      );
      final a = db.collection<Note>(
        id: (n) => n.id,
        toJson: (n) => n.toJson(),
        fromJson: Note.fromJson,
        type: 'note',
      );
      final b = db.collection<Note>(
        id: (n) => n.id,
        toJson: (n) => n.toJson(),
        fromJson: Note.fromJson,
        type: 'note',
      );
      expect(identical(a, b), isTrue);
      await db.dispose();
    });

    test('inline collection still syncs through the engine', () async {
      final remote = FakeSyncRemote();
      final db = SuperSync(
        store: InMemorySyncLocalStore(),
        remote: remote,
        autoSync: false,
      );
      final notes = db.collection<Note>(
        id: (n) => n.id,
        toJson: (n) => n.toJson(),
        fromJson: Note.fromJson,
        type: 'note',
      );

      await notes.save(const Note(id: 'n1', text: 'synced'));
      await notes.sync();

      expect(db.currentStatus.isFullySynced, isTrue);
      expect(remote.dataOf('note', 'n1')!['text'], 'synced');
      await db.dispose();
    });
  });
}
