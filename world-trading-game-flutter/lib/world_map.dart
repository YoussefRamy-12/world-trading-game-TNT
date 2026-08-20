import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/building.dart';
import 'models/country.dart';
import 'models/game.dart';
import 'models/player.dart';
import 'services/action_guard.dart';
import 'services/game_repository.dart';
import 'services/realtime_service.dart';

class WorldMapPage extends StatefulWidget {
  final Game game;
  const WorldMapPage({super.key, required this.game});

  @override
  State<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage> {
  static const maxLevel = 5;
  final repo = GameRepository();
  final guard = ActionGuard();
  final realtime = GameRealtimeService();
  Game? game;
  Player? player;
  List<Country> countries = [];
  List<BuildingType> buildingTypes = [];
  Map<String, List<CountryBuilding>> buildings = {};
  String? selectedId;
  bool loading = true;
  bool syncing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    game = widget.game;
    load();
    realtime.subscribe(
      gameId: widget.game.id,
      onChanged: _sync,
      onError: (_) {},
    );
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
        repo.fetchGame(widget.game.id),
        repo.fetchCurrentPlayer(),
        repo.fetchCountries(gameId: widget.game.id),
        repo.fetchBuildingTypes(),
      ]);
      game = results[0] as Game? ?? game;
      player = results[1] as Player?;
      countries = results[2] as List<Country>;
      buildingTypes = results[3] as List<BuildingType>;
      final next = <String, List<CountryBuilding>>{};
      for (final country in countries) {
        next[country.id] = await repo.fetchCountryBuildings(country.id);
      }
      buildings = next;
      if (selectedId != null && !countries.any((c) => c.id == selectedId)) {
        selectedId = null;
      }
    } catch (e) {
      error = e.toString();
    }
    if (showSpinner && mounted) setState(() => loading = false);
    if (!showSpinner && mounted) setState(() {});
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }

  int level(Country c) => (buildings[c.id]?.length ?? 0).clamp(1, maxLevel);

  int? get essentialId {
    if (buildingTypes.isEmpty) return null;
    return buildingTypes.map((b) => b.id).reduce(math.min);
  }

  Country? get selected => countries.where((c) => c.id == selectedId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final current = game ?? widget.game;
    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          _GameStateChip(state: current.state, tick: current.currentTick),
          const SizedBox(width: 8),
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final map = _MapBoard(
            countries: countries,
            selectedId: selectedId,
            currentPlayerId: player?.id,
            levels: {for (final c in countries) c.id: level(c)},
            onSelect: (c) => setState(() => selectedId = c.id),
          );
          final detail = selected == null
              ? const _MapHint()
              : _CountryDetail(
                  country: selected!,
                  player: player,
                  level: level(selected!),
                  buildings: buildings[selected!.id] ?? const [],
                  types: buildingTypes,
                  essentialId: essentialId,
                  guard: guard,
                  repo: repo,
                  onChanged: load,
                );
          if (wide) {
            return Row(children: [Expanded(child: map), SizedBox(width: 390, child: detail)]);
          }
          return Column(children: [Expanded(child: map), SizedBox(height: 300, child: detail)]);
        },
      ),
    );
  }
}

class _MapBoard extends StatelessWidget {
  final List<Country> countries;
  final String? selectedId;
  final String? currentPlayerId;
  final Map<String, int> levels;
  final ValueChanged<Country> onSelect;

  const _MapBoard({required this.countries, required this.selectedId, required this.currentPlayerId, required this.levels, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF06152B), Color(0xFF08263A)]),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _WorldPainter())),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, box) {
            final positions = _positions(countries.length);
            return Stack(children: [
              for (var i = 0; i < countries.length; i++)
                Positioned(
                  left: positions[i].dx * box.maxWidth - 38,
                  top: positions[i].dy * box.maxHeight - 20,
                  child: _CountryMarker(
                    country: countries[i],
                    level: levels[countries[i].id] ?? 1,
                    selected: countries[i].id == selectedId,
                    mine: countries[i].ownerPlayerId == currentPlayerId,
                    onTap: () => onSelect(countries[i]),
                  ),
                ),
            ]);
          }),
        ),
        Positioned(left: 20, top: 18, child: _MapLegend()),
        Positioned(right: 20, bottom: 18, child: Text('${countries.length} markets', style: const TextStyle(color: Colors.white70))),
      ]),
    );
  }

  List<Offset> _positions(int count) {
    const zones = <List<double>>[
      [0.20, 0.34], [0.34, 0.28], [0.48, 0.33], [0.62, 0.29], [0.77, 0.35],
      [0.25, 0.51], [0.40, 0.48], [0.55, 0.49], [0.68, 0.50], [0.81, 0.53],
      [0.35, 0.67], [0.50, 0.65], [0.65, 0.67], [0.76, 0.70], [0.46, 0.79],
    ];
    final result = <Offset>[];
    for (var i = 0; i < count; i++) {
      final z = zones[i % zones.length];
      final cycle = i ~/ zones.length;
      final dx = (z[0] + (cycle * 0.027)) % 0.86 + 0.04;
      final dy = (z[1] + ((cycle % 3) - 1) * 0.045).clamp(0.12, 0.86);
      result.add(Offset(dx, dy));
    }
    return result;
  }
}

class _CountryMarker extends StatelessWidget {
  final Country country;
  final int level;
  final bool selected;
  final bool mine;
  final VoidCallback onTap;

  const _CountryMarker({required this.country, required this.level, required this.selected, required this.mine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = mine ? Colors.cyanAccent : country.ownerPlayerId == null ? Colors.white70 : Colors.amberAccent;
    return Tooltip(
      message: '${country.name} • Level $level/5',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 86 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(.22) : const Color(0xDD071827),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent : accent.withOpacity(.55), width: selected ? 2 : 1),
            boxShadow: [BoxShadow(color: accent.withOpacity(.18), blurRadius: selected ? 18 : 8)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, size: selected ? 20 : 17, color: accent),
            Text(country.code?.toUpperCase() ?? 'WORLD', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
            Text('LV $level', style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }
}

class _WorldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(.035)..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 45) canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (var y = 0.0; y < size.height; y += 45) canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);

    final land = Paint()..color = const Color(0xFF123A43)..style = PaintingStyle.fill;
    final edge = Paint()..color = const Color(0xFF2A6570)..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final continents = [
      _blob(size, 0.22, 0.35, 0.19, 0.17),
      _blob(size, 0.39, 0.38, 0.13, 0.10),
      _blob(size, 0.29, 0.64, 0.12, 0.23),
      _blob(size, 0.52, 0.38, 0.17, 0.10),
      _blob(size, 0.61, 0.55, 0.17, 0.18),
      _blob(size, 0.78, 0.36, 0.15, 0.12),
      _blob(size, 0.78, 0.64, 0.16, 0.16),
      _blob(size, 0.58, 0.78, 0.10, 0.07),
    ];
    for (final path in continents) { canvas.drawPath(path, land); canvas.drawPath(path, edge); }
  }

  Path _blob(Size s, double cx, double cy, double rx, double ry) {
    final p = Path();
    const points = 18;
    for (var i = 0; i <= points; i++) {
      final a = 2 * math.pi * i / points;
      final wobble = 0.86 + 0.14 * math.sin(a * 3.0 + cx * 7);
      final x = s.width * (cx + math.cos(a) * rx * wobble);
      final y = s.height * (cy + math.sin(a) * ry * wobble);
      if (i == 0) p.moveTo(x, y); else p.lineTo(x, y);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: const Color(0xDD071827), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 9, color: Colors.cyanAccent), SizedBox(width: 5), Text('Yours'), SizedBox(width: 12),
      Icon(Icons.circle, size: 9, color: Colors.amberAccent), SizedBox(width: 5), Text('Owned'), SizedBox(width: 12),
      Icon(Icons.circle, size: 9, color: Colors.white70), SizedBox(width: 5), Text('Open'),
    ]),
  );
}

class _MapHint extends StatelessWidget {
  const _MapHint();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.touch_app, size: 42, color: Colors.cyanAccent),
      SizedBox(height: 12),
      Text('Select a country', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Tap a country marker on the world board to inspect ownership, value and buildings.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
    ]),
  );
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
        Row(children: [Expanded(child: Text(country.name, style: Theme.of(context).textTheme.headlineSmall)), IconButton(onPressed: onChanged, icon: const Icon(Icons.refresh))]),
        Text(country.code?.toUpperCase() ?? 'WORLD', style: const TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: _InfoCard('LEVEL', '$level / 5')), Expanded(child: _InfoCard('VALUE', country.value == null ? '—' : '\$${country.value}'))]),
        const SizedBox(height: 12),
        _OwnershipBanner(mine: mine, owner: country.ownerPlayerId == null ? 'Unowned' : mine ? 'Your country' : 'Another player'),
        const SizedBox(height: 18),
        const Text('Buildings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (buildings.isEmpty) const Text('Level 1 is the automatic essential building.', style: TextStyle(color: Colors.white70)),
        for (final b in buildings) _BuildingRow(type: types.where((t) => t.id == b.buildingTypeId).firstOrNull, essential: b.buildingTypeId == essentialId),
        if (mine && level < 5) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text('Build • Country Level $level → ${level + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Each new building adds one country level. A building type can only be used once.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          for (final type in available) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_business, color: Colors.cyanAccent),
            title: Text(type.name),
            subtitle: Text('Cost ${type.baseCost} • +1 country level'),
            trailing: FilledButton(onPressed: () => _build(context, type), child: const Text('Build')),
          ),
          if (available.isEmpty) const Text('No additional building types are available.', style: TextStyle(color: Colors.white70)),
        ],
        if (level >= 5) const Padding(padding: EdgeInsets.only(top: 18), child: Text('MAX LEVEL • 5/5', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Future<void> _build(BuildContext context, BuildingType type) async {
    try {
      await guard.run('map-build:${country.id}:${type.id}', () => repo.purchaseBuildings(countryId: country.id, buildingTypeId: type.id));
      await onChanged();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type.name} built. ${country.name} is now Level ${(buildings.length + 1).clamp(1, 5)}/5.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard(this.title, this.value);
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])));
}

class _OwnershipBanner extends StatelessWidget {
  final bool mine;
  final String owner;
  const _OwnershipBanner({required this.mine, required this.owner});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: mine ? Colors.cyan.withOpacity(.10) : Colors.white.withOpacity(.04)), child: Row(children: [Icon(mine ? Icons.verified : Icons.flag, color: mine ? Colors.cyanAccent : Colors.white70), const SizedBox(width: 10), Text(owner)]));
}

class _BuildingRow extends StatelessWidget {
  final BuildingType? type;
  final bool essential;
  const _BuildingRow({required this.type, required this.essential});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(essential ? Icons.account_balance : Icons.business, color: essential ? Colors.amberAccent : Colors.cyanAccent), title: Text(type?.name ?? 'Building'), subtitle: Text(essential ? 'Essential • automatic Level 1' : 'Installed building'));
}

class _GameStateChip extends StatelessWidget {
  final String state;
  final int tick;
  const _GameStateChip({required this.state, required this.tick});
  @override
  Widget build(BuildContext context) => Chip(avatar: const Icon(Icons.timelapse, size: 16), label: Text('${state.toUpperCase()} • TICK $tick'));
}
