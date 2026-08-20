import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_hub.dart';
import 'models/game.dart';
import 'services/action_guard.dart';
import 'services/auth_service.dart';
import 'services/game_repository.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (hasSupabaseConfig) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  validateSupabaseConfig();
  runApp(const WorldTradingGameApp());
}

class WorldTradingGameApp extends StatelessWidget {
  const WorldTradingGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'World Trading Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasSupabaseConfig) {
      return const _MessagePage(
        'Configure SUPABASE_URL and SUPABASE_ANON_KEY first.',
      );
    }

    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const AuthPage() : const LobbyPage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final auth = AuthService();
  bool signup = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (signup) {
        final displayName = name.text.trim();
        if (displayName.isEmpty) {
          throw StateError('Display name is required.');
        }
        await auth.signUp(
          email: email.text,
          password: password.text,
          displayName: displayName,
        );
      } else {
        await auth.signIn(email: email.text, password: password.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WORLD TRADING GAME',
                    style: TextStyle(
                      letterSpacing: 3,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signup ? 'Create account' : 'Sign in',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  if (signup) ...[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Please wait...'
                          : signup
                              ? 'Create account'
                              : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              signup = !signup;
                              error = null;
                            }),
                    child: Text(
                      signup
                          ? 'Already have an account? Sign in'
                          : 'Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final player = await repo.fetchCurrentPlayer();
      if (player == null) {
        final user = Supabase.instance.client.auth.currentUser;
        await repo.registerPlayer(
          displayName: user?.userMetadata?['display_name']?.toString() ??
              user?.email?.split('@').first ??
              'Player',
        );
      }
      games = await repo.fetchGames();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> join(Game game) async {
    try {
      await guard.run(
        'join:${game.id}',
        () => repo.joinGame(game.id),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameHubPage(game: game)),
      );
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  if (games.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No games available.'),
                      ),
                    ),
                  for (final game in games)
                    Card(
                      child: ListTile(
                        title: Text(game.name),
                        subtitle: Text(
                          '${game.state.toUpperCase()} • tick ${game.currentTick}',
                        ),
                        trailing: FilledButton(
                          onPressed: game.state == 'finished'
                              ? null
                              : () => join(game),
                          child: const Text('Join'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

void _snack(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString())),
  );
}

class _MessagePage extends StatelessWidget {
  final String message;

  const _MessagePage(this.message);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(message)));
  }
}
