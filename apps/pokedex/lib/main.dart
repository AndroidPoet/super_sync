import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:super_sync/super_sync.dart';
import 'package:super_sync_drift/super_sync_drift.dart';

import 'poke.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Sync · Pokédex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF12121A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SuperSync _sync;
  late final PokeApiSyncRemote _remote;
  late final SyncRepository<Pokemon> _repo;
  late final SyncPager<Pokemon> _pager;
  final ScrollController _scroll = ScrollController();

  bool _ready = false;
  int _bootCount = 0; // rows already in the local DB at launch
  String _message = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final db = SuperSyncDatabase(driftDatabase(name: 'pokedex'));
    _remote = PokeApiSyncRemote();
    _sync = SuperSync(
      store: DriftSyncLocalStore(db),
      remote: _remote,
      autoSync: false,
      config: const SyncConfig(pullPageSize: 20),
    )..register(PokemonSyncAdapter());
    await _sync.start();

    _repo = _sync.repository<Pokemon>();
    _bootCount = (await _repo.getAll()).length; // persisted from last run
    _pager = _repo.paged(pageSize: 24);

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        _pager.loadMore();
      }
    });

    setState(() => _ready = true);

    // First launch (empty DB) → pull from PokeAPI automatically. On later
    // launches the grid is served instantly from the local DB.
    if (_bootCount == 0) unawaited(_syncNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.dispose();
    _sync.dispose();
    _remote.close();
    super.dispose();
  }

  Future<void> _syncNow() async {
    setState(() => _message = 'Syncing from pokeapi.co …');
    await _sync.sync();
    setState(() => _message = 'Synced.');
  }

  Future<void> _addLocal() async {
    final n = DateTime.now().millisecondsSinceEpoch;
    await _repo.save(Pokemon(
      id: 'local_$n',
      name: 'custom-${n % 10000}',
      types: const ['psychic'],
      sprite: '',
      local: true,
    ));
  }

  // Hammer the store + engine concurrently to prove no race / no deadlock.
  Future<void> _stress() async {
    setState(() => _message = 'Stress: 200 concurrent writes + 3 syncs …');
    final base = DateTime.now().millisecondsSinceEpoch;
    final writes = <Future<void>>[
      for (var i = 0; i < 200; i++)
        _repo.save(Pokemon(
          id: 'stress_${base}_${i.toString().padLeft(3, '0')}',
          name: 'stress-$i',
          types: const ['steel'],
          sprite: '',
          local: true,
        )),
    ];
    // Fire concurrent syncs too: the engine's single-flight lock must serialize
    // them without deadlocking.
    final syncs = [_sync.sync(), _sync.sync(), _sync.sync()];
    await Future.wait([...writes, ...syncs]);
    final total = (await _repo.getAll()).length;
    setState(() => _message =
        'Stress done — no deadlock. Local DB now holds $total Pokémon.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Sync · Pokédex'),
        backgroundColor: const Color(0xFF1B1B2A),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _syncNow,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync from PokeAPI'),
            ),
          ),
          IconButton(
            tooltip: 'Stress test (races / deadlock)',
            onPressed: _stress,
            icon: const Icon(Icons.bolt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocal,
        icon: const Icon(Icons.add),
        label: const Text('Add local'),
      ),
      body: Column(
        children: [
          _StatusBar(sync: _sync, bootCount: _bootCount, message: _message),
          Expanded(
            child: StreamBuilder<SyncPage<Pokemon>>(
              stream: _pager.pages,
              builder: (context, snap) {
                final page = snap.data;
                if (page == null || (page.items.isEmpty && page.isLoading)) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (page.items.isEmpty) {
                  return const Center(
                    child: Text('No Pokémon yet — hit “Sync from PokeAPI”.'),
                  );
                }
                return GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: page.items.length + (page.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= page.items.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _PokemonCard(page.items[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.sync,
    required this.bootCount,
    required this.message,
  });

  final SuperSync sync;
  final int bootCount;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1B1B2A),
      child: StreamBuilder<SyncStatus>(
        stream: sync.status,
        builder: (context, snap) {
          final s = snap.data ?? sync.currentStatus;
          final synced = s.lastSyncedAt;
          return Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(
                icon: Icons.storage,
                label: 'Local DB · $bootCount on launch',
                color: const Color(0xFF6C5CE7),
              ),
              _Pill(
                icon: s.phase == SyncPhase.syncing
                    ? Icons.sync
                    : s.phase == SyncPhase.error
                        ? Icons.error_outline
                        : Icons.check_circle,
                label: 'phase: ${s.phase.name}',
                color: s.phase == SyncPhase.error
                    ? Colors.orange
                    : const Color(0xFF00B894),
              ),
              _Pill(
                icon: Icons.cloud_upload,
                label: 'pending: ${s.pendingChanges}',
                color: const Color(0xFF0984E3),
              ),
              if (s.deadLettered > 0)
                _Pill(
                  icon: Icons.report,
                  label: 'parked: ${s.deadLettered}',
                  color: Colors.orange,
                ),
              if (synced != null)
                _Pill(
                  icon: Icons.schedule,
                  label: 'synced ${synced.hour.toString().padLeft(2, '0')}:'
                      '${synced.minute.toString().padLeft(2, '0')}:'
                      '${synced.second.toString().padLeft(2, '0')}',
                  color: Colors.white24,
                ),
              if (message.isNotEmpty)
                Text(message, style: const TextStyle(color: Colors.white70)),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _PokemonCard extends StatelessWidget {
  const _PokemonCard(this.p);
  final Pokemon p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: p.sprite.isEmpty
                ? const Icon(Icons.catching_pokemon, size: 40)
                : Image.network(
                    p.sprite,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.catching_pokemon, size: 40),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (p.local)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.bolt, size: 14, color: Colors.amber),
                      ),
                  ],
                ),
                Text('#${p.id}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final t in p.types)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t, style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
