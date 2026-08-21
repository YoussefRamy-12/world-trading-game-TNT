import 'package:flutter/material.dart';

import 'admin_console.dart';
import 'models/game.dart';
import 'services/action_guard.dart';
import 'services/game_repository.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final repo = GameRepository();
  final guard = ActionGuard();
  List<Game> games = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final result = await repo.fetchGames();
      if (mounted) setState(() { games = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> createGame() async {
    final name = TextEditingController(text: 'World Trading Game');
    final slug = TextEditingController(text: 'world-trading-game-${DateTime.now().millisecondsSinceEpoch}');
    final tick = TextEditingController(text: '3600');
    final startingBalance = TextEditingController(text: '100000');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Create New Game'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Game name')),
          TextField(controller: slug, decoration: const InputDecoration(labelText: 'Game slug')),
          TextField(controller: tick, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tick interval (seconds)')),
          TextField(controller: startingBalance, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Starting balance (cents)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, {
            'name': name.text.trim(),
            'slug': slug.text.trim(),
            'tick': int.tryParse(tick.text.trim()) ?? 3600,
            'starting': int.tryParse(startingBalance.text.trim()) ?? 100000,
          }), child: const Text('Create')),
        ],
      ),
    );
    name.dispose(); slug.dispose(); tick.dispose(); startingBalance.dispose();
    if (result == null) return;
    try {
      await guard.run('admin:create-game', () => repo.adminCreateGame(
        name: result['name'] as String,
        slug: result['slug'] as String,
        tickIntervalSeconds: result['tick'] as int,
        startingBalance: result['starting'] as int,
      ));
      await load();
      if (mounted) _snack('Game created as DRAFT. Configure it, then press Ready.');
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  void openGame(Game game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminConsolePage(
      gameId: game.id,
      repository: repo,
      guard: guard,
      onChanged: load,
    ))).then((_) => load());
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createGame, icon: const Icon(Icons.add), label: const Text('New Game')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('Retry'))]))
              : games.isEmpty
                  ? const Center(child: Text('No games yet. Create the first game.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: games.length,
                      itemBuilder: (_, i) {
                        final game = games[i];
                        return Card(child: ListTile(
                          leading: Icon(game.state == 'running' ? Icons.play_circle : Icons.sports_esports),
                          title: Text(game.name),
                          subtitle: Text('${game.state.toUpperCase()} • ${game.slug} • tick ${game.currentTick}'),
                          trailing: FilledButton(onPressed: () => openGame(game), child: const Text('Manage')),
                        ));
                      },
                    ),
    );
  }
}
