import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';
import 'services/action_guard.dart';
import 'models/game.dart';
import 'models/country.dart';
import 'models/building.dart';

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
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF020617),
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const RootPage(),
      );
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});
  @override
  Widget build(BuildContext context) {
    if (!hasSupabaseConfig) return const _MessagePage('Configure SUPABASE_URL and SUPABASE_ANON_KEY first.');
    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (_, snapshot) => Supabase.instance.client.auth.currentSession == null
          ? const AuthPage()
          : const LobbyPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool signup = false, busy = false;
  String? error;
  final auth = AuthService();
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (signup) await auth.signUp(email: email.text, password: password.text);
      else await auth.signIn(email: email.text, password: password.text);
    } catch (e) { setState(() => error = e.toString()); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('WORLD TRADING GAME', style: TextStyle(letterSpacing: 3, color: Colors.cyanAccent)), const SizedBox(height: 8),
    Text(signup ? 'Create account' : 'Sign in', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 20),
    if (signup) TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')), if (signup) const SizedBox(height: 12),
    TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 12),
    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')), const SizedBox(height: 16),
    if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)), const SizedBox(height: 8),
    FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : signup ? 'Create account' : 'Sign in')),
    TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }), child: Text(signup ? 'Already have an account? Sign in' : 'Create an account')),
  ]))))));
}

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});
  @override State<LobbyPage> createState() => _LobbyPageState();
}
class _LobbyPageState extends State<LobbyPage> {
  final repo = GameRepository();
  final guard = ActionGuard();
  List<Game> games = [];
  bool loading = true;
  String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { games = await repo.fetchGames(); } catch (e) { error = e.toString(); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> join(Game game) async {
    try {
      await guard.run('join:${game.id}', () => repo.joinGame(game.id));
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(game: game)));
    } catch (e) { if (mounted) _snack(context, e); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Game Lobby'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), IconButton(onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout))]), body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(20), children: [
    if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
    if (games.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No games available.'))),
    for (final game in games) Card(child: ListTile(title: Text(game.name), subtitle: Text('${game.state.toUpperCase()} • tick ${game.currentTick}'), trailing: FilledButton(onPressed: game.state == 'finished' ? null : () => join(game), child: const Text('Join')))),
  ]));
}

class GamePage extends StatefulWidget {
  final Game game;
  const GamePage({super.key, required this.game});
  @override State<GamePage> createState() => _GamePageState();
}
class _GamePageState extends State<GamePage> {
  final repo = GameRepository();
  final guard = ActionGuard();
  late Game game;
  List<Country> countries = [];
  List<BuildingType> buildingTypes = [];
  Map<String, List<CountryBuilding>> buildings = {};
  bool loading = true;
  @override void initState() { super.initState(); game = widget.game; load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await Future.wait([repo.fetchGame(game.id), repo.fetchCountries(gameId: game.id), repo.fetchBuildingTypes()]);
      game = data[0] as Game? ?? game;
      countries = data[1] as List<Country>;
      buildingTypes = data[2] as List<BuildingType>;
      for (final c in countries) { buildings[c.id] = await repo.fetchCountryBuildings(c.id); }
    } catch (e) { if (mounted) _snack(context, e); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> buy(Country c, BuildingType type) async {
    final existing = buildings[c.id]!.any((b) => b.buildingTypeId == type.id);
    if (existing) { _snack(context, 'This building already exists on this country. Only one is allowed.'); return; }
    try {
      await guard.run('buy-building:${c.id}:${type.id}', () => repo.purchaseBuildings(countryId: c.id, buildingTypeId: type.id, quantity: 1));
      await load();
      if (mounted) _snack(context, '${type.name} built on ${c.name}.');
    } catch (e) { if (mounted) _snack(context, e); }
  }
  Future<void> upgrade(Country c, CountryBuilding b) async {
    final countryHasUpgrade = buildings[c.id]!.any((x) => x.level > 1);
    if (countryHasUpgrade) { _snack(context, 'This country has already used its one upgrade.'); return; }
    final type = buildingTypes.where((x) => x.id == b.buildingTypeId).firstOrNull;
    if (type == null || type.maxLevel <= b.level) { _snack(context, 'This building cannot be upgraded further.'); return; }
    try {
      await guard.run('upgrade:${b.id}', () => repo.upgradeBuilding(countryBuildingId: b.id, newLevel: b.level + 1));
      await load();
      if (mounted) _snack(context, '${type.name} upgraded on ${c.name}.');
    } catch (e) { if (mounted) _snack(context, e); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(game.name), actions: [Chip(label: Text('Tick ${game.currentTick}')), IconButton(onPressed: load, icon: const Icon(Icons.refresh))]), body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.public, size: 36), const SizedBox(width: 12), Expanded(child: Text('World board', style: Theme.of(context).textTheme.headlineSmall)), Text('${countries.length} countries')]))),
    const SizedBox(height: 12),
    for (final c in countries) Card(child: ExpansionTile(title: Text(c.name), subtitle: Text(c.ownerPlayerId == null ? 'Unowned' : 'Owned'), children: [
      ListTile(title: const Text('Country value'), trailing: Text(c.value == null ? '—' : '\$${c.value}')),
      if (buildings[c.id]!.isNotEmpty) ...[for (final b in buildings[c.id]!) Builder(builder: (_) { final type = buildingTypes.where((x) => x.id == b.buildingTypeId).firstOrNull; return ListTile(leading: const Icon(Icons.business), title: Text(type?.name ?? 'Building'), subtitle: Text('Level ${b.level}'), trailing: b.level == 1 && (type?.maxLevel ?? 1) > 1 ? OutlinedButton(onPressed: () => upgrade(c, b), child: const Text('Upgrade')) : const Text('Upgraded')); })],
      if (c.ownerPlayerId == Supabase.instance.client.auth.currentUser?.id) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Divider(), const Text('Build on this country', style: TextStyle(fontWeight: FontWeight.bold)), for (final type in buildingTypes) if (!buildings[c.id]!.any((b) => b.buildingTypeId == type.id)) ListTile(title: Text(type.name), subtitle: Text('Cost: ${type.baseCost}'), trailing: FilledButton(onPressed: () => buy(c, type), child: const Text('Build')))])),
    ])),
  ]));
}

void _snack(BuildContext context, Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));

class _MessagePage extends StatelessWidget {
  final String message;
  const _MessagePage(this.message);
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text(message)));
}
