import 'dart:io';

import 'package:drift/native.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_codegen/super_sync_codegen.dart';
import 'package:super_sync_drift/super_sync_drift.dart';
import 'package:test/test.dart';

import 'golden/app_models.dart';

class _EchoRemote implements SyncRemote {
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

/// Locate the package root whether tests run from the package dir (local) or
/// the workspace root (CI).
String _base() {
  for (final c in ['.', 'packages/super_sync_codegen']) {
    if (File('$c/example/openapi.yaml').existsSync()) return c;
  }
  throw StateError('cannot locate super_sync_codegen package root');
}

void main() {
  test('generated output matches the committed golden file', () {
    final base = _base();
    final spec = File('$base/example/openapi.yaml').readAsStringSync();
    final golden = File('$base/test/golden/app_models.dart').readAsStringSync();
    expect(generateFromOpenApi(spec), golden);
  });

  test('generated models + AppSync drive the engine end to end', () async {
    final sync = SuperSync(
      store: InMemorySyncLocalStore(),
      remote: _EchoRemote(),
      autoSync: false,
    );
    registerSuperSyncModels(sync); // the single generated wiring call
    await sync.start();

    final app = AppSync(sync); // the single generated typed API

    await app.todos.save(
      const Todo(id: 't1', title: 'Buy milk', completed: false, tags: ['home']),
    );
    await app.users.save(const User(id: 'u1', name: 'Ranbir', age: 30));
    await app.messages.save(const Message(id: 'm1', text: 'hi'));

    expect((await app.todos.get('t1'))!.title, 'Buy milk');
    expect((await app.todos.get('t1'))!.tags, ['home']);
    expect((await app.users.get('u1'))!.age, 30);
    expect((await app.messages.get('m1'))!.text, 'hi');

    await sync.sync();
    expect(sync.currentStatus.isFullySynced, isTrue);
    await sync.dispose();
  });

  test('generated models also run over the Drift (SQLite) store', () async {
    // Same generated code, swapped onto the durable store — proving the output
    // is store-agnostic and covers both the in-memory and Drift databases.
    final sync = SuperSync(
      store: DriftSyncLocalStore(SuperSyncDatabase(NativeDatabase.memory())),
      remote: _EchoRemote(),
      autoSync: false,
    );
    registerSuperSyncModels(sync);
    await sync.start();

    final app = AppSync(sync);
    await app.todos.save(
      const Todo(id: 't1', title: 'Buy milk', completed: false, tags: ['home']),
    );
    expect((await app.todos.get('t1'))!.tags, ['home']);
    await sync.sync();
    expect(sync.currentStatus.isFullySynced, isTrue);
    await sync.dispose();
  });

  test('throws when a schema has no id property', () {
    const spec = '''
openapi: 3.0.0
info: {title: x, version: 1.0.0}
paths: {}
components:
  schemas:
    NoId:
      type: object
      properties:
        name: {type: string}
''';
    expect(() => generateFromOpenApi(spec), throwsA(isA<FormatException>()));
  });
}
