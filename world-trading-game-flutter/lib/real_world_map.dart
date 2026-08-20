import 'package:flutter/material.dart';
import 'package:interactive_world_map/interactive_world_map.dart';

import 'models/building.dart';
import 'models/country.dart';
import 'models/game.dart';
import 'models/player.dart';
import 'services/action_guard.dart';
import 'services/game_repository.dart';
import 'services/realtime_service.dart';

class RealWorldMapPage extends StatefulWidget {
  final Game game;
  const RealWorldMapPage({super.key, required this.game});

  @override
  State<RealWorldMapPage> createState() => _RealWorldMapPageState();
}

class _RealWorldMapPageState extends State<RealWorldMapPage> {
  static const maxLevel = 5;
  final repo = GameRepository();
  final guard = ActionGuard();
  final realtime = GameRealtimeService();
  Player? player;
  List<Country> countries = [];
  List<BuildingType> buildingTypes = [];
  Map<String, List<CountryBuilding>> buildings = {};
  String? selectedCountryId;
  bool loading = true;
  bool syncing = false;
  WorldMapController? mapController;

  @override
  void initState() {
    super.initState();
    load();
    realtime.subscribe(gameId: widget.game.id, onChanged: _sync, onError: (_) {});
  }

  Future<void> _sync() async {
    if (!mounted || syncing) return;
    syncing = true;
    try {
      await load(showSpinner: false);
    } finally {
      syncing = false;
    }
  }

  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => loading = true);
    try {
      final results = await Future.wait([
        repo.fetchCurrentPlayer(),
        repo.fetchCountries(gameId: widget.game.id),
        repo.fetchBuildingTypes(),
      ]);
      player = results[0] as Player?;
      countries = results[1] as List<Country>;
      buildingTypes = results[2] as List<BuildingType>;
      final next = <String, List<CountryBuilding>>{};
      for (final country in countries) {
        next[country.id] = await repo.fetchCountryBuildings(country.id);
      }
      buildings = next;
    } catch (_) {}
    if (showSpinner && mounted) setState(() => loading = false);
    if (!showSpinner && mounted) setState(() {});
  }

  int level(Country country) => (buildings[country.id]?.length ?? 0).clamp(1, maxLevel);

  int? get essentialId => buildingTypes.isEmpty ? null : buildingTypes.map((b) => b.id).reduce((a, b) => a < b ? a : b);

  Country? get selected => countries.where((c) => c.id == selectedCountryId).firstOrNull;

  String? _mapId(Country country) {
    final code = country.code?.trim().toUpperCase();
    if (code == null || code.isEmpty) return null;
    return defaultMapIdResolver(code);
  }

  Country? _countryForMapId(String mapId) {
    for (final country in countries) {
      final id = _mapId(country);
      if (id == mapId || country.code?.toUpperCase() == mapId.toUpperCase()) return country;
    }
    return null;
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final selectedCountry = selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.name),
        actions: [Chip(label: Text('${widget.game.state.toUpperCase()} • TICK ${widget.game.currentTick}')), const SizedBox(width: 8), IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        final map = _WorldMapCanvas(
          countries: countries,
          levels: {for (final c in countries) c.id: level(c)},
          playerId: player?.id,
          selectedId: selectedCountry?.id,
          onReady: (controller) => mapController = controller,
          onTap: (mapId) {
            final country = _countryForMapId(mapId);
            if (country != null) setState(() => selectedCountryId = country.id);
          },
        );
        final detail = selectedCountry == null
            ? const _EmptySelection()
            : _CountryDetail(country: selectedCountry, player: player, level: level(selectedCountry), buildings: buildings[selectedCountry.id] ?? const [], types: buildingTypes, essentialId: essentialId, guard: guard, repo: repo, onChanged: load);
        if (wide) return Row(children: [Expanded(child: map), SizedBox(width: 390, child: detail)]);
        return Column(children: [Expanded(child: map), SizedBox(height: 320, child: detail)]);
      }),
    );
  }
}

class _WorldMapCanvas extends StatelessWidget {
  final List<Country> countries;
  final Map<String, int> levels;
  final String? playerId;
  final String? selectedId;
  final ValueChanged<WorldMapController> onReady;
  final ValueChanged<String> onTap;

  const _WorldMapCanvas({required this.countries, required this.levels, required this.playerId, required this.selectedId, required this.onReady, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visible = countries.map((c) => c.code?.trim().toUpperCase()).whereType<String>().where((c) => c.isNotEmpty).toSet();
    final controller = WorldMapController();
    onReady(controller);
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF06111E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: InteractiveWorldMap(
              controller: controller,
              visibleCountryIds: visible.map(defaultMapIdResolver).whereType<String>().toSet(),
              selectOnTap: true,
              toggleSelectionOnTap: true,
              onCountryTap: onTap,
              style: const WorldMapStyle(),
            ),
          ),
        ),
        Positioned(top: 18, left: 18, child: _Legend()),
        Positioned(bottom: 18, right: 18, child: Text('${countries.length} countries', style: const TextStyle(color: Colors.white70))),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xDD071827),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 9, color: Colors.cyanAccent), SizedBox(width: 5), Text('Your country'), SizedBox(width: 14),
            Icon(Icons.touch_app, size: 14, color: Colors.white70), SizedBox(width: 5), Text('Tap country'),
          ]),
        ),
      );
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.public, size: 48, color: Colors.cyanAccent), SizedBox(height: 12), Text('Select a country', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Tap any country on the real world map to inspect it.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))])));
}

class _CountryDetail extends StatelessWidget {
  final Country country;
  final Player? player;
  final int level;
  final List<CountryBuilding> buildings;
  final List<BuildingType> types;
  final int? essentialId;
  final ActionGuard guard;
  final GameRepository repo;
  final Future<void> Function() onChanged;

  const _CountryDetail({required this.country, required this.player, required this.level, required this.buildings, required this.types, required this.essentialId, required this.guard, required this.repo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final mine = country.ownerPlayerId == player?.id;
    final available = types.where((t) => t.id != essentialId && !buildings.any((b) => b.buildingTypeId == t.id)).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFF06111E), border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
      child: ListView(children: [
        Row(children: [Expanded(child: Text(country.name, style: Theme.of(context).textTheme.headlineSmall)), Text(country.code?.toUpperCase() ?? '')]),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _StatCard('LEVEL', '$level / 5')), Expanded(child: _StatCard('VALUE', country.value == null ? '—' : '\$${country.value}'))]),
        const SizedBox(height: 12),
        ListTile(leading: Icon(mine ? Icons.verified : Icons.flag, color: mine ? Colors.cyanAccent : Colors.white70), title: Text(country.ownerPlayerId == null ? 'Unowned' : mine ? 'Your country' : 'Owned by another player')),
        const SizedBox(height: 10),
        const Text('Buildings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (buildings.isEmpty) const Text('Level 1 is the automatic essential building.', style: TextStyle(color: Colors.white70)),
        for (final b in buildings) Builder(builder: (_) {
          final type = types.where((t) => t.id == b.buildingTypeId).firstOrNull;
          return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(b.buildingTypeId == essentialId ? Icons.account_balance : Icons.business, color: b.buildingTypeId == essentialId ? Colors.amberAccent : Colors.cyanAccent), title: Text(type?.name ?? 'Building'), subtitle: Text(b.buildingTypeId == essentialId ? 'Essential • automatic Level 1' : 'Installed building'));
        }),
        if (mine && level < 5) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text('Build • Level $level → ${level + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Each unique building adds one country level. Buildings themselves are not upgraded.', style: TextStyle(color: Colors.white70)),
          for (final type in available) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.add_business, color: Colors.cyanAccent), title: Text(type.name), subtitle: Text('Cost ${type.baseCost} • +1 level'), trailing: FilledButton(onPressed: () => _build(context, type), child: const Text('Build'))),
          if (available.isEmpty) const Text('No additional building types available.', style: TextStyle(color: Colors.white70)),
        ],
        if (level >= 5) const Padding(padding: EdgeInsets.only(top: 12), child: Text('MAX LEVEL • 5/5', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Future<void> _build(BuildContext context, BuildingType type) async {
    try {
      await guard.run('real-map-build:${country.id}:${type.id}', () => repo.purchaseBuildings(countryId: country.id, buildingTypeId: type.id));
      await onChanged();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type.name} built. ${country.name} is now Level ${level + 1}/5.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard(this.title, this.value);
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])));
}
