import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard.dart';
import 'main.dart' show LobbyPage;
import 'services/admin_repository_extensions.dart';
import 'services/game_repository.dart';

class PostLoginRouter extends StatefulWidget {
  const PostLoginRouter({super.key});

  @override
  State<PostLoginRouter> createState() => _PostLoginRouterState();
}

class _PostLoginRouterState extends State<PostLoginRouter> {
  final repo = GameRepository();
  bool loading = true;
  bool bootstrapAvailable = false;
  bool? isAdmin;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      var player = await repo.fetchCurrentPlayer();
      if (player == null) {
        final user = Supabase.instance.client.auth.currentUser;
        await repo.registerPlayer(
          displayName: user?.userMetadata?['display_name']?.toString() ??
              user?.email?.split('@').first ?? 'Player',
        );
        player = await repo.fetchCurrentPlayer();
      }
      final anyAdmin = await repo.hasAnyAdmin();
      if (!mounted) return;
      setState(() {
        isAdmin = player?.isAdmin == true;
        bootstrapAvailable = !anyAdmin;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> bootstrap() async {
    setState(() => loading = true);
    try {
      await repo.bootstrapFirstAdmin();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() { error = e.toString(); loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('Retry'))])));
    }
    if (isAdmin == true) return const AdminDashboardPage();
    if (bootstrapAvailable) return _BootstrapPage(onBootstrap: bootstrap);
    return const LobbyPage();
  }
}

class _BootstrapPage extends StatelessWidget {
  final VoidCallback onBootstrap;
  const _BootstrapPage({required this.onBootstrap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.admin_panel_settings, size: 56),
                const SizedBox(height: 16),
                Text('Game setup is not initialized', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text('No administrator exists yet. The first authorized account should become the game administrator, create the game, configure it, and mark it Ready before players join.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: onBootstrap, icon: const Icon(Icons.admin_panel_settings), label: const Text('Become Game Admin')),
                const SizedBox(height: 8),
                const Text('Only the first administrator can use this setup step.', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
