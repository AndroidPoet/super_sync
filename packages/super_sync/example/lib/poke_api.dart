import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_sync/super_sync.dart';

/// A Pokémon — an ordinary model. Super Sync knows nothing about it.
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.height,
    required this.weight,
  });

  final String id;
  final String name;
  final List<String> types;
  final int height;
  final int weight;

  @override
  String toString() =>
      '#$id  ${name.padRight(12)}  '
      '${types.join('/').padRight(16)}  h:$height w:$weight';
}

/// The ~10-line adapter that teaches Super Sync this model.
class PokemonSyncAdapter implements SyncEntityAdapter<Pokemon> {
  @override
  String get type => 'pokemon';

  @override
  String idOf(Pokemon v) => v.id;

  @override
  Map<String, Object?> encode(Pokemon v) => {
    'id': v.id,
    'name': v.name,
    'types': v.types,
    'height': v.height,
    'weight': v.weight,
  };

  @override
  Pokemon decode(Map<String, Object?> d) => Pokemon(
    id: d['id']! as String,
    name: d['name']! as String,
    types: (d['types']! as List).cast<String>(),
    height: d['height']! as int,
    weight: d['weight']! as int,
  );
}

/// A real, read-only [SyncRemote] backed by https://pokeapi.co.
///
/// Proves the engine drives an actual paginated HTTP API with zero changes:
/// [pull] walks the `?offset=&limit=` pages (the cursor *is* the offset) and
/// enriches each entry with a details fetch. PokeAPI is read-only, so [push] is
/// a no-op — the engine simply never gets acks it doesn't need.
class PokeApiSyncRemote implements SyncRemote {
  PokeApiSyncRemote({this.maxPokemon = 40});

  /// Cap so the demo stops instead of pulling all ~1300 species.
  final int maxPokemon;

  final http.Client _client = http.Client();

  /// How many pull pages the engine fetched.
  int pullCalls = 0;

  @override
  Future<PushResponse> push(List<SyncMutation> mutations) async {
    // Read-only backend.
    return const PushResponse([]);
  }

  @override
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  }) async {
    pullCalls++;
    final offset = cursor == null ? 0 : int.parse(cursor);
    final pageSize = limit ?? 20;
    final remaining = maxPokemon - offset;
    if (remaining <= 0) {
      return PullResponse(changes: const [], nextCursor: cursor);
    }
    final take = remaining < pageSize ? remaining : pageSize;

    final listResp = await _client.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon?offset=$offset&limit=$take'),
    );
    final list = jsonDecode(listResp.body) as Map<String, Object?>;
    final results = (list['results']! as List).cast<Map<String, Object?>>();

    // Enrich each entry concurrently — one details fetch per Pokémon.
    final changes = await Future.wait(
      results.map((entry) async {
        final detail =
            jsonDecode(
                  (await _client.get(Uri.parse(entry['url']! as String))).body,
                )
                as Map<String, Object?>;
        final id = (detail['id']! as int).toString();
        final types = (detail['types']! as List)
            .cast<Map<String, Object?>>()
            .map((t) => (t['type']! as Map<String, Object?>)['name']! as String)
            .toList();
        return RemoteChange(
          entityType: 'pokemon',
          entityId: id,
          operation: SyncOperation.update,
          serverVersion: 1,
          data: {
            'id': id,
            'name': detail['name']! as String,
            'types': types,
            'height': detail['height']! as int,
            'weight': detail['weight']! as int,
          },
        );
      }),
    );

    final nextOffset = offset + take;
    return PullResponse(
      changes: changes,
      nextCursor: nextOffset.toString(),
      hasMore: nextOffset < maxPokemon,
    );
  }

  void close() => _client.close();
}
