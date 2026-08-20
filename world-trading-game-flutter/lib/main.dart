import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/game_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (hasSupabaseConfig) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  validateSupabaseConfig();
  runApp(const WorldTradingGameApp());
}

class WorldTradingGameApp extends StatelessWidget {
  const WorldTradingGameApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'World Trading Game',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF020617), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF06B6D4), brightness: Brightness.dark), useMaterial3: true),
    home: const GamePage(),
  );
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameState game;
  @override
  void initState() { super.initState(); game = GameState()..load(); }
  @override
  void dispose() { game.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: AnimatedBuilder(animation: game, builder: (_, __) {
    if (game.loading && game.countries.isEmpty) return const Center(child: CircularProgressIndicator());
    if (game.error != null && game.countries.isEmpty) return _ErrorState(message: game.error!, retry: game.load);
    return _Dashboard(countries: game.countries, refresh: game.load);
  })));
}

class _Dashboard extends StatelessWidget {
  final List<dynamic> countries;
  final Future<void> Function() refresh;
  const _Dashboard({required this.countries, required this.refresh});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxWidth < 900;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header(count: countries.length, refresh: refresh), const SizedBox(height: 16),
      if (compact) ...[_WorldBoard(countries: countries), const SizedBox(height: 16), _CountryList(countries: countries)]
      else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: _WorldBoard(countries: countries)), const SizedBox(width: 16), Expanded(flex: 3, child: _CountryList(countries: countries))]),
    ]))));
  });
}

class _Header extends StatelessWidget {
  final int count; final Future<void> Function() refresh;
  const _Header({required this.count, required this.refresh});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('WORLD TRADING GAME', style: TextStyle(letterSpacing: 3, fontSize: 12, color: Colors.cyanAccent)), SizedBox(height: 4), Text('Global Economic Strategy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]),), Chip(label: Text('$count countries loaded')), IconButton(onPressed: () => refresh(), icon: const Icon(Icons.refresh))]));
}

class _WorldBoard extends StatelessWidget {
  final List<dynamic> countries;
  const _WorldBoard({required this.countries});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('World Map', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 14), Container(height: 330, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const RadialGradient(colors: [Color(0xFF12334A), Color(0xFF0F172A), Color(0xFF020617)]), border: Border.all(color: Colors.white12)), child: Center(child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [for (final c in countries.take(24)) Chip(avatar: const Icon(Icons.public, size: 16), label: Text(c.name))])))])));
}

class _CountryList extends StatelessWidget {
  final List<dynamic> countries;
  const _CountryList({required this.countries});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Countries from Supabase', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 12), if (countries.isEmpty) const Text('No public countries found.') else ...[for (final c in countries) ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text(c.code ?? '🌐')), title: Text(c.name), subtitle: Text('Population: ${c.population}'), trailing: c.value == null ? null : Text('\$${c.value}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)))] ])));
}

class _ErrorState extends StatelessWidget {
  final String message; final Future<void> Function() retry;
  const _ErrorState({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 48), const SizedBox(height: 12), const Text('Could not load game data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SelectableText(message, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: () => retry(), child: const Text('Retry'))])));
}
