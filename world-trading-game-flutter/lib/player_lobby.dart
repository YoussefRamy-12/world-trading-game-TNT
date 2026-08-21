import 'package:flutter/material.dart';

import 'game_hub.dart';
import 'models/game.dart';
import 'services/action_guard.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';

class PlayerLobbyPage extends StatefulWidget {
  const PlayerLobbyPage({super.key});

  @override
  State<PlayerLobbyPage> createState() => _PlayerLobbyPageState();
}

class _PlayerLobbyPageState extends State<PlayerLobbyPage> {
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
      final allGames = await repo.fetchGames();
      games = allGames.where((game) => game.state == 'ready' || game.state == 'running').toList();
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> join(Game game) async {
    try {
      await guard.run('join:${game.id}', () => repo.joinGame(game.id));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => GameHubPage(game: game)));
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  void _snack(Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Only games prepared by the administrator and marked READY are shown here.'))),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
                if (games.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No games are ready yet. Please wait for the administrator to prepare the game.'))),
                for (final game in games) Card(child: ListTile(
                  leading: Icon(game.state == 'running' ? Icons.play_circle : Icons.hourglass_top),
                  title: Text(game.name),
                  subtitle: Text(game.state == 'running' ? 'GAME RUNNING • tick ${game.currentTick}' : 'READY • waiting for players'),
                  trailing: FilledButton(onPressed: () => join(game), child: const Text('Join')),
                )),
              ]),
            ),
    );
  }
}
