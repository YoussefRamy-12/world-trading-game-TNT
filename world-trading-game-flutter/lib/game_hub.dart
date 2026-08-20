import 'package:flutter/material.dart';

import 'models/country.dart';
import 'models/game.dart';
import 'models/marketplace.dart';
import 'models/player.dart';
import 'services/action_guard.dart';
import 'services/game_repository.dart';
import 'services/realtime_service.dart';
import 'real_world_map.dart';
import 'admin_console.dart';

class GameHubPage extends StatefulWidget {
  final Game game;
  const GameHubPage({super.key, required this.game});
  @override
  State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  final repo = GameRepository();
  final guard = ActionGuard();
  final realtime = GameRealtimeService();
  int index = 0;
  late Game game;
  Player? player;
  List<Country> countries = [];
  List<CountryListing> listings = [];
  List<Map<String, dynamic>> netWorths = [];
  int? walletBalance;
  bool loading = true;
  bool refreshing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    game = widget.game;
    load();
    realtime.subscribe(gameId: game.id, onChanged: () => load(showSpinner: false), onError: (_) {});
  }

  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() { loading = true; error = null; });
    if (refreshing) return;
    refreshing = true;
    try {
      final freshGame = await repo.fetchGame(game.id);
      final freshPlayer = await repo.fetchCurrentPlayer();
      final freshCountries = await repo.fetchCountries(gameId: game.id);
      final freshListings = await repo.fetchListings();
      final freshNetWorths = await repo.fetchNetWorths(game.id);
      final balance = freshPlayer == null ? null : await repo.fetchWalletBalance(freshPlayer.id);
      if (!mounted) return;
      setState(() {
        game = freshGame ?? game;
        player = freshPlayer;
        countries = freshCountries;
        listings = freshListings;
        netWorths = freshNetWorths;
        walletBalance = balance;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      refreshing = false;
      if (showSpinner && mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null && countries.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(game.name)), body: _ErrorState(message: error!, onRetry: load));
    }

    final pages = [
      RealWorldMapPage(game: game),
      _PortfolioPage(player: player, countries: countries, netWorths: netWorths, walletBalance: walletBalance, repository: repo, guard: guard, onChanged: load),
      _MarketplacePage(player: player, countries: countries, listings: listings, repository: repo, guard: guard, onChanged: load),
      _LeaderboardPage(player: player, netWorths: netWorths),
      if (player?.isAdmin == true) AdminConsolePage(gameId: game.id, repository: repo, guard: guard, onChanged: load),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.public), label: 'World'),
      const NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
      const NavigationDestination(icon: Icon(Icons.storefront), label: 'Market'),
      const NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Ranking'),
      if (player?.isAdmin == true) const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];

    if (index >= pages.length) index = 0;
    return Scaffold(
      body: SafeArea(child: Column(children: [
        _GameStatusBar(game: game, balance: walletBalance, onRefresh: load),
        Expanded(child: pages[index]),
      ])),
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value), destinations: destinations),
    );
  }
}

class _GameStatusBar extends StatelessWidget {
  final Game game;
  final int? balance;
  final VoidCallback onRefresh;
  const _GameStatusBar({required this.game, required this.balance, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(game.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Chip(label: Text(game.state.toUpperCase())),
        Chip(avatar: const Icon(Icons.timelapse, size: 16), label: Text('Tick ${game.currentTick}')),
        if (balance != null) Chip(avatar: const Icon(Icons.account_balance_wallet, size: 16), label: Text('Cash \$$balance')),
        IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
      ]),
    );
  }
}

class _PortfolioPage extends StatelessWidget {
  final Player? player;
  final List<Country> countries;
  final List<Map<String, dynamic>> netWorths;
  final int? walletBalance;
  final GameRepository repository;
  final ActionGuard guard;
  final Future<void> Function() onChanged;
  const _PortfolioPage({required this.player, required this.countries, required this.netWorths, required this.walletBalance, required this.repository, required this.guard, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final owned = countries.where((c) => c.ownerPlayerId == player?.id).toList();
    final row = netWorths.where((r) => r['player_id']?.toString() == player?.id).firstOrNull;
    final netWorth = _number(row?['net_worth']);
    final countryValue = owned.fold<int>(0, (sum, c) => sum + (c.value ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('My Portfolio')),
      body: RefreshIndicator(onRefresh: onChanged, child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(player?.displayName.isNotEmpty == true ? player!.displayName : 'Player', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 850 ? 4 : c.maxWidth >= 520 ? 2 : 1;
          return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.3, children: [
            _Stat(title: 'Cash', value: walletBalance == null ? '—' : '\$$walletBalance', icon: Icons.account_balance_wallet),
            _Stat(title: 'Countries', value: '${owned.length}', icon: Icons.public),
            _Stat(title: 'Country value', value: '\$$countryValue', icon: Icons.trending_up),
            _Stat(title: 'Net worth', value: '\$$netWorth', icon: Icons.auto_graph),
          ]);
        }),
        const SizedBox(height: 24),
        Text('My Countries', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (owned.isEmpty) const Card(child: ListTile(title: Text('No countries owned yet.'))),
        for (final country in owned) Card(child: ListTile(
          leading: const Icon(Icons.flag),
          title: Text(country.name),
          subtitle: Text('Value: ${country.value == null ? '—' : '\$${country.value}'}'),
          trailing: FilledButton.tonal(onPressed: () => _showSellDialog(context, country), child: const Text('Sell')),
        )),
      ])),
    );
  }
  Future<void> _showSellDialog(BuildContext context, Country country) async {
    final controller = TextEditingController(text: '${country.value ?? 0}');
    final price = await showDialog<int>(context: context, builder: (dialogContext) => AlertDialog(title: Text('List ${country.name} for sale'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', prefixText: '\$')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, int.tryParse(controller.text.trim())), child: const Text('List'))]));
    controller.dispose();
    if (price == null || price <= 0) return;
    try { await guard.run('sell:${country.id}', () => repository.sellCountry(countryId: country.id, price: price)); await onChanged(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Country listed for sale.'))); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
}

class _MarketplacePage extends StatelessWidget {
  final Player? player;
  final List<Country> countries;
  final List<CountryListing> listings;
  final GameRepository repository;
  final ActionGuard guard;
  final Future<void> Function() onChanged;
  const _MarketplacePage({required this.player, required this.countries, required this.listings, required this.repository, required this.guard, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final open = listings.where((l) => l.status == 'open').toList();
    return Scaffold(appBar: AppBar(title: const Text('Marketplace'), actions: [IconButton(onPressed: onChanged, icon: const Icon(Icons.refresh))]), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Buy or list countries using the existing atomic marketplace transactions.'))),
      const SizedBox(height: 12),
      if (open.isEmpty) const Card(child: ListTile(title: Text('No countries are currently listed.'))),
      for (final listing in open) _listingCard(context, listing),
    ]));
  }
  Widget _listingCard(BuildContext context, CountryListing listing) {
    final country = countries.where((c) => c.id == listing.countryId).firstOrNull;
    final mine = listing.sellerPlayerId == player?.id;
    return Card(child: ListTile(leading: const Icon(Icons.public), title: Text(country?.name ?? 'Country'), subtitle: Text('${listing.currency} ${listing.price} • ${mine ? 'Your listing' : 'Listed by another player'}'), trailing: mine ? const Chip(label: Text('Yours')) : FilledButton(onPressed: () async { try { await guard.run('buy:${listing.id}', () => repository.buyCountry(listing.id)); await onChanged(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Country purchased.'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }, child: const Text('Buy'))));
  }
}

class _LeaderboardPage extends StatelessWidget {
  final Player? player;
  final List<Map<String, dynamic>> netWorths;
  const _LeaderboardPage({required this.player, required this.netWorths});
  @override
  Widget build(BuildContext context) {
    final rows = [...netWorths]..sort((a, b) => _number(b['net_worth']).compareTo(_number(a['net_worth'])));
    return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: ListView(padding: const EdgeInsets.all(20), children: [
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ranking is calculated from the existing net-worth RPC, so cash and country value stay consistent with the game database.'))),
      for (var i = 0; i < rows.length; i++) _rankTile(i + 1, rows[i]),
      if (rows.isEmpty) const Card(child: ListTile(title: Text('Leaderboard is not available yet.'))),
    ]));
  }
  Widget _rankTile(int rank, Map<String, dynamic> row) {
    final mine = row['player_id']?.toString() == player?.id;
    final name = (row['display_name'] ?? row['player_name'] ?? 'Player $rank').toString();
    return Card(child: ListTile(leading: CircleAvatar(child: Text('$rank')), title: Text(name, style: TextStyle(fontWeight: mine ? FontWeight.bold : FontWeight.normal)), subtitle: mine ? const Text('You') : null, trailing: Text('\$${_number(row['net_worth'])}')));
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _Stat({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))])));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 48), const SizedBox(height: 12), const Text('Could not load the game.'), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: onRetry, child: const Text('Retry'))])));
}

int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
