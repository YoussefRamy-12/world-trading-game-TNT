import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

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
          seedColor: const Color(0xFF06B6D4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 16),
                      if (compact)
                        const Column(
                          children: [
                            _WorldBoard(),
                            SizedBox(height: 16),
                            _Lobby(),
                            SizedBox(height: 16),
                            _CountryDetails(),
                            SizedBox(height: 16),
                            _Portfolio(),
                            SizedBox(height: 16),
                            _Marketplace(),
                            SizedBox(height: 16),
                            _Leaderboard(),
                          ],
                        )
                      else ...[
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _WorldBoard()),
                            SizedBox(width: 16),
                            Expanded(flex: 3, child: _Lobby()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _CountryDetails()),
                            SizedBox(width: 16),
                            Expanded(flex: 4, child: _Portfolio()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _Marketplace()),
                            SizedBox(width: 16),
                            Expanded(flex: 4, child: _Leaderboard()),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WORLD TRADING GAME', style: TextStyle(letterSpacing: 3, fontSize: 12, color: Color(0xFF67E8F9))),
              SizedBox(height: 4),
              Text('Global Economic Strategy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _StatChip(label: 'Cash', value: '\$12,450', icon: Icons.account_balance_wallet_outlined),
              _StatChip(label: 'Reputation', value: '⭐ 320', icon: Icons.star_outline),
              _StatChip(label: 'Day', value: '2', icon: Icons.calendar_today_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorldBoard extends StatelessWidget {
  const _WorldBoard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'World Map',
      subtitle: 'Live country ownership and market activity.',
      trailing: const _Badge('Game running'),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const RadialGradient(colors: [Color(0xFF12334A), Color(0xFF0F172A), Color(0xFF020617)]),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _CountryPill('🇪🇬', 'Egypt'),
              _CountryPill('🇫🇷', 'France'),
              _CountryPill('🇬🇧', 'UK'),
              _CountryPill('🇯🇵', 'Japan'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby();

  @override
  Widget build(BuildContext context) {
    const players = [('🇪🇬', 'Player A', 'Ready', '\$12,450'), ('🇫🇷', 'Player B', 'In game', '\$11,680'), ('🇬🇧', 'Player C', 'Ready', '\$10,910'), ('🇯🇵', 'Player D', 'Away', '\$9,840')];
    return _Panel(title: 'Lobby', subtitle: 'Players and game status', child: Column(children: [for (final p in players) _PlayerRow(p.$1, p.$2, p.$3, p.$4)]));
  }
}

class _CountryDetails extends StatelessWidget {
  const _CountryDetails();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Country details',
      subtitle: 'Egypt • Tier: Gold • Daily income: \$620',
      child: Column(
        children: [
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric('Price', '\$8,400'),
              _Metric('Income', '\$620 / hr'),
              _Metric('Owner', 'You'),
              _Metric('Buildings', '4 / 6'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: () {}, child: const Text('BUY')),
            FilledButton.tonal(onPressed: () {}, child: const Text('UPGRADE')),
            OutlinedButton(onPressed: () {}, child: const Text('LIST')),
            OutlinedButton(onPressed: () {}, child: const Text('BID')),
          ]),
        ],
      ),
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio();

  @override
  Widget build(BuildContext context) {
    const countries = [('🇪🇬', 'Egypt', 'You', '\$8,400', '+\$620/hr'), ('🇫🇷', 'France', 'Player B', '\$11,840', '+\$560/hr'), ('🇬🇧', 'UK', 'Player C', '\$10,190', '+\$470/hr'), ('🇯🇵', 'Japan', 'Player D', '\$9,420', '+\$430/hr')];
    return _Panel(title: 'My Countries', subtitle: 'Selected nation portfolio', child: Column(children: [for (final c in countries) _PortfolioRow(c.$1, c.$2, c.$3, c.$4, c.$5)]));
  }
}

class _Marketplace extends StatelessWidget {
  const _Marketplace();

  @override
  Widget build(BuildContext context) {
    const listings = [('Egypt', 'Player A', '\$8,400', '\$7,900', 'Open'), ('Brazil', 'Player C', '\$6,300', '\$5,800', 'Open'), ('Canada', 'Player D', '\$5,900', '\$4,700', 'Bid')];
    return _Panel(title: 'Marketplace', subtitle: 'Available listings, bids, and open offers', child: Column(children: [for (final l in listings) _ListingRow(l.$1, l.$2, l.$3, l.$4, l.$5)]));
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context) {
    const entries = [('Player A', '\$12,450', '+\$1,200'), ('Player B', '\$11,680', '+\$980'), ('Player C', '\$10,910', '+\$730'), ('Player D', '\$9,840', '+\$610')];
    return _Panel(title: 'Leaderboard', subtitle: 'Top players by net worth', child: Column(children: [for (var i = 0; i < entries.length; i++) _LeaderboardRow(i + 1, entries[i].$1, entries[i].$2, entries[i].$3)]));
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => _Panel(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Wrap(spacing: 8, children: [Chip(label: Text('My Countries')), Chip(label: Text('Market')), Chip(label: Text('Ranking'))]), Text('Realtime: Live', style: TextStyle(color: Colors.greenAccent.shade200))]));
}

class _Panel extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  const _Panel({required this.child, this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xCC0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title!, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 12))])), if (trailing != null) trailing!]),
            const SizedBox(height: 14),
          ],
          child,
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.cyanAccent), const SizedBox(width: 7), Text('$label: '), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: .1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyan.withValues(alpha: .3))), child: Text(text, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)));
}

class _CountryPill extends StatelessWidget {
  final String flag;
  final String name;
  const _CountryPill(this.flag, this.name);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xCC0F172A), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white12)), child: Text('$flag  $name'));
}

class _PlayerRow extends StatelessWidget {
  final String flag, name, status, score;
  const _PlayerRow(this.flag, this.name, this.status, this.score);
  @override
  Widget build(BuildContext context) => _RowCard(child: Row(children: [Text(flag, style: const TextStyle(fontSize: 23)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w600)), Text(status, style: const TextStyle(color: Colors.white54, fontSize: 11))])), Text(score, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))]));
}

class _PortfolioRow extends StatelessWidget {
  final String flag, name, owner, value, income;
  const _PortfolioRow(this.flag, this.name, this.owner, this.value, this.income);
  @override
  Widget build(BuildContext context) => _RowCard(child: Row(children: [Text(flag, style: const TextStyle(fontSize: 23)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name), Text(owner, style: const TextStyle(color: Colors.white54, fontSize: 11))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)), Text(income, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))]) ]));
}

class _ListingRow extends StatelessWidget {
  final String country, seller, price, bid, status;
  const _ListingRow(this.country, this.seller, this.price, this.bid, this.status);
  @override
  Widget build(BuildContext context) => _RowCard(child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(country, style: const TextStyle(fontWeight: FontWeight.w600)), Text('Seller: $seller', style: const TextStyle(color: Colors.white54, fontSize: 11))]), Text('Price $price', style: const TextStyle(color: Colors.cyanAccent)), Text('Bid $bid', style: const TextStyle(color: Colors.greenAccent)), _Badge(status)]));
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String player, netWorth, trend;
  const _LeaderboardRow(this.rank, this.player, this.netWorth, this.trend);
  @override
  Widget build(BuildContext context) => _RowCard(child: Row(children: [CircleAvatar(radius: 16, child: Text('$rank')), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player), Text(trend, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))])), Text(netWorth, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))]));
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(width: 150, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0x99020617), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])));
}

class _RowCard extends StatelessWidget {
  final Widget child;
  const _RowCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0x99020617), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)), child: child);
}
