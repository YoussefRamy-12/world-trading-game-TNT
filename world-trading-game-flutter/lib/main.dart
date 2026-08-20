import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';
import 'services/action_guard.dart';
import 'models/game.dart';
import 'models/country.dart';
import 'models/building.dart';
import 'models/player.dart';
import 'game_hub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (hasSupabaseConfig) await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  validateSupabaseConfig();
  runApp(const WorldTradingGameApp());
}

class WorldTradingGameApp extends StatelessWidget {
  const WorldTradingGameApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'World Trading Game',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF020617), colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark), useMaterial3: true),
    home: const RootPage(),
  );
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});
  @override Widget build(BuildContext context) {
    if (!hasSupabaseConfig) return const _MessagePage('Configure SUPABASE_URL and SUPABASE_ANON_KEY first.');
    return StreamBuilder<AuthState>(stream: AuthService().authStateChanges, builder: (_, __) => Supabase.instance.client.auth.currentSession == null ? const AuthPage() : const LobbyPage());
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController();
  bool signup = false, busy = false;
  String? error;
  final auth = AuthService();
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (signup) {
        await auth.signUp(email: email.text, password: password.text);
        // The lobby registers the player after authentication. Keep the typed name
        // in the auth metadata so the existing player-registration flow can use it.
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null && name.text.trim().isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'display_name': name.text.trim()}));
        }
      } else {
        await auth.signIn(email: email.text, password: password.text);
      }
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('WORLD TRADING GAME', style: TextStyle(letterSpacing: 3, color: Colors.cyanAccent)), const SizedBox(height: 8),
    Text(signup ? 'Create account' : 'Sign in', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 20),
    if (signup) TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')), if (signup) const SizedBox(height: 12),
    TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')), const SizedBox(height: 16),
    if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)), const SizedBox(height: 8), FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : signup ? 'Create account' : 'Sign in')),
    TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }), child: Text(signup ? 'Already have an account? Sign in' : 'Create an account')),
  ]))))));
}

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});
  @override State<LobbyPage> createState() => _LobbyPageState();
}
class _LobbyPageState extends State<LobbyPage> {
  final repo = GameRepository(), guard = ActionGuard();
  List<Game> games = []; bool loading = true; String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      var player = await repo.fetchCurrentPlayer();
      if (player == null) {
        final user = Supabase.instance.client.auth.currentUser;
        final displayName = user?.userMetadata?['display_name']?.toString().trim();
        await repo.registerPlayer(displayName: (displayName == null || displayName.isEmpty) ? user?.email?.split('@').first ?? 'Player' : displayName);
        player = await repo.fetchCurrentPlayer();
      }
      games = await repo.fetchGames();
    } catch (e) { error = e.toString(); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> join(Game game) async {
    try {
      await guard.run('join:${game.id}', () => repo.joinGame(game.id));
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => GameHubPage(game: game, worldPageBuilder: (game) => GamePage(game: game))));
    } catch (e) { if (mounted) _snack(context, e); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Game Lobby'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), IconButton(onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout))]), body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(20), children: [
    if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)), if (games.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No games available.'))),
    for (final game in games) Card(child: ListTile(title: Text(game.name), subtitle: Text('${game.state.toUpperCase()} • tick ${game.currentTick}'), trailing: FilledButton(onPressed: game.state == 'finished' ? null : () => join(game), child: const Text('Join')))),
  ]));
}

class GamePage extends StatefulWidget {
  final Game game;
  const GamePage({super.key, required this.game});
  @override State<GamePage> createState() => _GamePageState();
}
class _GamePageState extends State<GamePage> {
  static const int maxCountryLevel = 5;
  final repo = GameRepository(), guard = ActionGuard();
  late Game game; Player? player; List<Country> countries = []; List<BuildingType> buildingTypes = []; Map<String, List<CountryBuilding>> buildings = {}; bool loading = true;
  @override void initState() { super.initState(); game = widget.game; load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await Future.wait([repo.fetchGame(game.id), repo.fetchCurrentPlayer(), repo.fetchCountries(gameId: game.id), repo.fetchBuildingTypes()]);
      game = data[0] as Game? ?? game; player = data[1] as Player?; countries = data[2] as List<Country>; buildingTypes = data[3] as List<BuildingType>;
      buildings = {};
      for (final c in countries) buildings[c.id] = await repo.fetchCountryBuildings(c.id);
    } catch (e) { if (mounted) _snack(context, e); }
    if (mounted) setState(() => loading = false);
  }
  int countryLevel(Country country) {
    final count = buildings[country.id]?.length ?? 0;
    return count.clamp(1, maxCountryLevel);
  }
  int? get essentialBuildingTypeId {
    if (buildingTypes.isEmpty) return null;
    return buildingTypes.map((type) => type.id).reduce((a, b) => a < b ? a : b);
  }
  Future<void> addBuilding(Country country, BuildingType type) async {
    final currentBuildings = buildings[country.id] ?? const <CountryBuilding>[];
    final level = countryLevel(country);
    if (country.ownerPlayerId != player?.id) { _snack(context, 'You can only build on countries you own.'); return; }
    if (type.id == essentialBuildingTypeId) { _snack(context, '${type.name} is the automatic Level 1 building.'); return; }
    if (currentBuildings.any((b) => b.buildingTypeId == type.id)) { _snack(context, 'Only one ${type.name} can exist on the same country.'); return; }
    if (level >= maxCountryLevel) { _snack(context, 'This country is already Level $maxCountryLevel.'); return; }
    try {
      await guard.run('add-building:${country.id}:${type.id}', () => repo.purchaseBuildings(countryId: country.id, buildingTypeId: type.id, quantity: 1));
      await load();
      if (mounted) _snack(context, '${type.name} added to ${country.name}. Country is now Level ${countryLevel(country)}.');
    } catch (e) { if (mounted) _snack(context, e); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(game.name), actions: [Chip(label: Text('Tick ${game.currentTick}')), IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.public, size: 36), const SizedBox(width: 12), const Expanded(child: Text('World board', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), Text('${countries.length} countries')]))), const SizedBox(height: 12),
      for (final country in countries) _countryCard(country),
    ]),
  );
  Widget _countryCard(Country country) {
    final countryBuildings = buildings[country.id] ?? const <CountryBuilding>[];
    final level = countryLevel(country); final ownedByMe = country.ownerPlayerId == player?.id;
    return Card(child: ExpansionTile(title: Row(children: [Expanded(child: Text(country.name)), _LevelBadge(level: level, maxLevel: maxCountryLevel)]), subtitle: Text(country.ownerPlayerId == null ? 'Unowned' : ownedByMe ? 'Your country' : 'Owned'), children: [
      ListTile(leading: const Icon(Icons.trending_up), title: const Text('Country level'), subtitle: Text(level == 1 ? 'Raw country / essential building' : '${countryBuildings.length} buildings installed'), trailing: Text('$level / $maxCountryLevel', style: const TextStyle(fontWeight: FontWeight.bold))),
      ListTile(title: const Text('Country value'), trailing: Text(country.value == null ? '—' : '\$${country.value}')),
      if (countryBuildings.isNotEmpty) for (final building in countryBuildings) Builder(builder: (_) { final type = buildingTypes.where((x) => x.id == building.buildingTypeId).firstOrNull; final isEssential = building.buildingTypeId == essentialBuildingTypeId; return ListTile(leading: Icon(isEssential ? Icons.account_balance : Icons.business), title: Text(type?.name ?? 'Building'), subtitle: Text(isEssential ? 'Essential • Level 1' : 'Building added at country Level ${countryBuildings.indexOf(building) + 1}')); }),
      if (ownedByMe) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _buildSection(country, countryBuildings, level)),
    ]));
  }
  Widget _buildSection(Country country, List<CountryBuilding> currentBuildings, int level) {
    final canBuild = level < maxCountryLevel;
    final available = buildingTypes.where((type) => type.id != essentialBuildingTypeId && !currentBuildings.any((b) => b.buildingTypeId == type.id)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(), Row(children: [const Expanded(child: Text('Add a building', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), Text('Level $level → ${canBuild ? level + 1 : level}')]),
      const SizedBox(height: 6), const Text('Each new building upgrades the country by one level. Buildings themselves do not have upgrade levels.'), const SizedBox(height: 8),
      if (!canBuild) const ListTile(leading: Icon(Icons.verified), title: Text('Maximum country level reached'), subtitle: Text('All 5 building levels are complete.')),
      if (canBuild && available.isEmpty) const ListTile(leading: Icon(Icons.info_outline), title: Text('No more buildings available')),
      if (canBuild) for (final type in available) ListTile(title: Text(type.name), subtitle: Text('Cost: ${type.baseCost} • Country becomes Level ${level + 1}'), trailing: FilledButton(onPressed: () => addBuilding(country, type), child: const Text('Build'))),
    ]);
  }
}

class _LevelBadge extends StatelessWidget {
  final int level; final int maxLevel;
  const _LevelBadge({required this.level, required this.maxLevel});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent)), child: Text('LV $level/$maxLevel', style: const TextStyle(fontWeight: FontWeight.bold)));
}

void _snack(BuildContext context, Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
class _MessagePage extends StatelessWidget { final String message; const _MessagePage(this.message); @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text(message))); }
