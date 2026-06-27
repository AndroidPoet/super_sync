import 'package:super_sync/super_sync.dart';
import 'package:super_sync_example/poke_api.dart';

/// End-to-end demo against the live PokeAPI:
///   dart run example/bin/poke.dart
Future<void> main() async {
  final remote = PokeApiSyncRemote();
  final sync = SuperSync(
    store: InMemorySyncLocalStore(),
    remote: remote,
    autoSync: false,
    config: const SyncConfig(pullPageSize: 20),
  )..register(PokemonSyncAdapter());
  await sync.start();

  final pokedex = sync.repository<Pokemon>();

  print('Syncing from https://pokeapi.co ...');
  await sync.sync();
  print('  pull pages : ${remote.pullCalls}');
  print('  status     : ${sync.currentStatus}');

  final all = await pokedex.getAll();
  print('\nCaught ${all.length} Pokémon and cached them locally:\n');
  for (final p in all) {
    print('  $p');
  }

  // Reads now come from the local store — no network.
  final pikachu = await pokedex.get('25');
  print('\nLocal lookup #25 -> ${pikachu?.name} (${pikachu?.types.join('/')})');

  // Pagination over the local cache: keyset, reactive, smooth.
  print('\nPaging the local cache, 12 at a time:');
  final pager = pokedex.paged(pageSize: 12);
  final sub = pager.pages.listen((page) {
    print(
      '  window=${page.items.length}  hasMore=${page.hasMore}  '
      'loading=${page.isLoading}',
    );
  });
  await Future<void>.delayed(Duration.zero);
  await pager.loadMore();
  await pager.loadMore();

  await sub.cancel();
  await pager.dispose();
  await sync.dispose();
  remote.close();
}
