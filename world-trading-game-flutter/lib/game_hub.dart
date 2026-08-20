import 'package:flutter/material.dart';
import 'models/country.dart';
import 'models/game.dart';
import 'models/marketplace.dart';
import 'models/player.dart';
import 'services/action_guard.dart';
import 'services/game_repository.dart';

class GameHubPage extends StatefulWidget {
  final Game game;
  final Widget Function(Game game) worldPageBuilder;
  const GameHubPage({super.key, required this.game, required this.worldPageBuilder});
  @override State<GameHubPage> createState() => _GameHubPageState();
}

class _GameHubPageState extends State<GameHubPage> {
  int index = 0;
  final repo = GameRepository();
  final guard = ActionGuard();
  Player? player;
  List<Country> countries = [];
  List<CountryListing> listings = [];
  List<Map<String, dynamic>> netWorths = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      player = await repo.fetchCurrentPlayer();
      countries = await repo.fetchCountries(gameId: widget.game.id);
      listings = await repo.fetchListings();
      netWorths = await repo.fetchNetWorths(widget.game.id);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      widget.worldPageBuilder(widget.game),
      _PortfolioPage(player: player, countries: countries, netWorths: netWorths),
      _MarketplacePage(player: player, countries: countries, listings: listings, repository: repo, guard: guard, onChanged: load),
      _LeaderboardPage(player: player, netWorths: netWorths),
    ];
    return Scaffold(
      body: loading ? const Center(child: CircularProgressIndicator()) : pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.public), label: 'World'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Ranking'),
        ],
      ),
    );
  }
}

class _PortfolioPage extends StatelessWidget {
  final Player? player;
  final List<Country> countries;
  final List<Map<String, dynamic>> netWorths;
  const _PortfolioPage({required this.player, required this.countries, required this.netWorths});

  @override
  Widget build(BuildContext context) {
    final owned = countries.where((c) => c.ownerPlayerId == player?.id).toList();
    final row = netWorths.where((r) => r['player_id']?.toString() == player?.id).firstOrNull;
    final netWorth = row?['net_worth'];
    final countryValue = owned.fold<int>(0, (sum, c) => sum + (c.value ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('My Portfolio')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(player?.displayName.isNotEmpty == true ? player!.displayName : 'Player', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (_, constraints) {
            final compact = constraints.maxWidth < 700;
            final stats = [
              _Stat(title: 'Countries', value: '${owned.length}', icon: Icons.public),
              _Stat(title: 'Country value', value: '\$$countryValue', icon: Icons.trending_up),
              _Stat(title: 'Net worth', value: netWorth == null ? '—' : '\$$netWorth', icon: Icons.account_balance_wallet),
            ];
            return compact ? Column(children: [for (final s in stats) Padding(padding: const EdgeInsets.only(bottom: 8), child: s)]) : Row(children: [for (var i = 0; i < stats.length; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : 12), child: stats[i]))]);
          }),
        ]))),
        const SizedBox(height: 12),
        Text('My Countries', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (owned.isEmpty) const Card(child: ListTile(title: Text('No countries owned yet.'))),
        for (final country in owned) Card(child: ListTile(leading: const Icon(Icons.flag), title: Text(country.name), subtitle: Text('Country value: ${country.value == null ? '—' : '\$${country.value}'}'))),
      ]),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace'), actions: [IconButton(onPressed: onChanged, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Buy countries from other players. Marketplace actions use the existing Supabase RPCs.'))),
        const SizedBox(height: 12),
        if (open.isEmpty) const Card(child: ListTile(title: Text('No countries are currently listed.'))),
        for (final listing in open) _listingCard(context, listing),
      ]),
    );
  }

  Widget _listingCard(BuildContext context, CountryListing listing) {
    final country = countries.where((c) => c.id == listing.countryId).firstOrNull;
    final mine = listing.sellerPlayerId == player?.id;
    return Card(child: ListTile(
      leading: const Icon(Icons.public),
      title: Text(country?.name ?? 'Country'),
      subtitle: Text('${listing.currency} ${listing.price} • ${mine ? 'Your listing' : 'Listed by another player'}'),
      trailing: mine ? const Chip(label: Text('Yours')) : FilledButton(
        onPressed: () async {
          try {
            await guard.run('buy:${listing.id}', () => repository.buyCountry(listing.id));
            await onChanged();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Country purchased.')));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        },
        child: const Text('Buy'),
      ),
    ));
  }
}

class _LeaderboardPage extends StatelessWidget {
  final Player? player;
  final List<Map<String, dynamic>> netWorths;
  const _LeaderboardPage({required this.player, required this.netWorths});

  @override
  Widget build(BuildContext context) {
    final rows = [...netWorths]..sort((a, b) => _number(b['net_worth']).compareTo(_number(a['net_worth'])));
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Ranking is calculated from the existing game net-worth function.'))),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) _rankTile(i + 1, rows[i]),
        if (rows.isEmpty) const Card(child: ListTile(title: Text('Leaderboard is not available yet.'))),
      ]),
    );
  }

  Widget _rankTile(int rank, Map<String, dynamic> row) {
    final id = row['player_id']?.toString();
    final mine = id == player?.id;
    final name = (row['display_name'] ?? row['player_name'] ?? 'Player $rank').toString();
    final worth = _number(row['net_worth']);
    return Card(child: ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text(name, style: TextStyle(fontWeight: mine ? FontWeight.bold : FontWeight.normal)),
      subtitle: mine ? const Text('You') : null,
      trailing: Text('\$$worth', style: const TextStyle(fontWeight: FontWeight.bold)),
    ));
  }
}

class _Stat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _Stat({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(title), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
  );
}

int _number(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
