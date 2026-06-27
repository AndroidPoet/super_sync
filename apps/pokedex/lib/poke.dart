import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:super_sync/super_sync.dart';

/// The domain model. Super Sync knows nothing about it.
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.sprite,
    this.local = false,
  });

  final String id;
  final String name;
  final List<String> types;
  final String sprite;
  final bool local;
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
        'sprite': v.sprite,
        'local': v.local,
      };

  @override
  Pokemon decode(Map<String, Object?> d) => Pokemon(
        id: d['id']! as String,
        name: d['name']! as String,
        types: (d['types']! as List).cast<String>(),
        sprite: (d['sprite'] as String?) ?? '',
        local: (d['local'] as bool?) ?? false,
      );
}

/// A real, read-only [SyncRemote] backed by https://pokeapi.co.
class PokeApiSyncRemote implements SyncRemote {
  PokeApiSyncRemote({this.maxPokemon = 60});

  final int maxPokemon;
  final http.Client _client = http.Client();

  @override
  Future<PushResponse> push(List<SyncMutation> mutations) async {
    // PokeAPI is read-only: locally-added Pokémon simply stay pending.
    return const PushResponse([]);
  }

  @override
  Future<PullResponse> pull({
    String? cursor,
    Set<String>? entityTypes,
    int? limit,
  }) async {
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

    final changes = await Future.wait(
      results.map((entry) async {
        final detail = jsonDecode(
          (await _client.get(Uri.parse(entry['url']! as String))).body,
        ) as Map<String, Object?>;
        final id = (detail['id']! as int).toString().padLeft(4, '0');
        final types = (detail['types']! as List)
            .cast<Map<String, Object?>>()
            .map((t) => (t['type']! as Map<String, Object?>)['name']! as String)
            .toList();
        final sprites = detail['sprites']! as Map<String, Object?>;
        return RemoteChange(
          entityType: 'pokemon',
          entityId: id,
          operation: SyncOperation.update,
          serverVersion: 1,
          data: {
            'id': id,
            'name': detail['name']! as String,
            'types': types,
            'sprite': (sprites['front_default'] as String?) ?? '',
            'local': false,
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
