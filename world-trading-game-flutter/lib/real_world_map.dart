import 'package:flutter/material.dart';
import 'package:world_map/world_map.dart';

import 'models/country.dart';

class WorldMapController {}

class RealWorldMap extends StatelessWidget {
  final List<Country> countries;
  final Map<String, int> levels;
  final String? playerId;
  final String? selectedId;
  final ValueChanged<String> onTap;
  final ValueChanged<WorldMapController> onReady;

  const RealWorldMap({
    super.key,
    required this.countries,
    required this.levels,
    required this.playerId,
    required this.selectedId,
    required this.onTap,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return _WorldMapCanvas(
      countries: countries,
      levels: levels,
      playerId: playerId,
      selectedId: selectedId,
      onReady: onReady,
      onTap: onTap,
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

  const _WorldMapCanvas({
    required this.countries,
    required this.levels,
    required this.playerId,
    required this.selectedId,
    required this.onReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visible = countries
        .map((c) => c.code?.trim().toUpperCase())
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet();
    final controller = WorldMapController();
    onReady(controller);
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF06111E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: InteractiveWorldMap(
                controller: controller,
                visibleCountryIds: visible
                    .map(defaultMapIdResolver)
                    .whereType<String>()
                    .toSet(),
                selectOnTap: true,
                toggleSelectionOnTap: true,
                onCountryTap: onTap,
                style: const WorldMapStyle(),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: _Legend(),
          ),
          Positioned(
            bottom: 18,
            right: 18,
            child: Text(
              '${countries.length} countries',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('Tap a country to select it'),
      ),
    );
  }
}
