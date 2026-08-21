import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/action_guard.dart';
import 'services/admin_repository_extensions.dart';
import 'services/game_repository.dart';

class AdminConsolePage extends StatefulWidget {
  final String gameId;
  final GameRepository repository;
  final ActionGuard guard;
  final Future<void> Function() onChanged;
  const AdminConsolePage({super.key, required this.gameId, required this.repository, required this.guard, required this.onChanged});
  @override State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  int tab = 0;

  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final result = await widget.repository.fetchAdminGameData(widget.gameId);
      if (mounted) setState(() { data = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  List<Map<String, dynamic>> rows(String key) => ((data[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Map<String, dynamic> get game => Map<String, dynamic>.from((data['game'] as Map?) ?? const {});

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(appBar: AppBar(title: const Text('Game Admin')), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('Retry'))])));
    final pages = [_overview(), _players(), _countries(), _buildings(), _settings(), _marketplace()];
    return Scaffold(
      appBar: AppBar(title: Text(game['name']?.toString() ?? 'Game Admin'), actions: [IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh)), IconButton(tooltip: 'Logout', onPressed: _logout, icon: const Icon(Icons.logout))]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Players'),
        NavigationDestination(icon: Icon(Icons.public), label: 'Countries'),
        NavigationDestination(icon: Icon(Icons.apartment), label: 'Buildings'),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        NavigationDestination(icon: Icon(Icons.storefront), label: 'Market'),
      ]),
    );
  }

  Widget _overview() {
    final ps = rows('players'), cs = rows('countries'), bs = rows('country_buildings');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Game setup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6), const Text('Configure the game before players start.'), const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [_stat('Players', ps.length, Icons.people), _stat('Countries', cs.length, Icons.public), _stat('Buildings', bs.length, Icons.apartment)]),
      ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        ListTile(title: const Text('Game status'), subtitle: Text('${game['state'] ?? 'draft'} • Tick ${game['current_tick'] ?? 0}')),
        const Divider(height: 1),
        _action('Mark Ready', Icons.check_circle_outline, () => widget.repository.setGameReady(widget.gameId)),
        _action('Start Game', Icons.play_arrow, () => widget.repository.startGame(widget.gameId)),
        _action('Pause Game', Icons.pause, () => widget.repository.pauseGame(widget.gameId)),
        _action('Resume Game', Icons.play_circle, () => widget.repository.resumeGame(widget.gameId)),
      ])),
    ]);
  }

  Widget _players() {
    final ps = rows('players'), ws = rows('wallets');
    return _page('Player Balances', [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Add or remove money directly from each player. Quick buttons are in USD; use Adjust for any amount.', style: Theme.of(context).textTheme.bodyLarge))),
      for (final p in ps) _playerCard(p, ws),
      if (ps.isEmpty) const Card(child: ListTile(title: Text('No players yet.'))),
    ]);
  }

  Widget _playerCard(Map<String, dynamic> p, List<Map<String, dynamic>> wallets) {
    final cents = _walletCents(wallets, p['id']);
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(child: Text(_initial(p['display_name']))), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['display_name'] ?? 'Player'}${p['is_admin'] == true ? ' • ADMIN' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text('Balance: ${_money(cents)} USD', style: Theme.of(context).textTheme.titleMedium),
        ])),
        IconButton(tooltip: 'Edit player', onPressed: () => _editPlayer(p), icon: const Icon(Icons.edit)),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _moneyButton('+100', 100, p), _moneyButton('+500', 500, p), _moneyButton('+1,000', 1000, p),
        _moneyButton('-100', -100, p), _moneyButton('-500', -500, p), _moneyButton('-1,000', -1000, p),
        OutlinedButton.icon(onPressed: () => _customBalance(p), icon: const Icon(Icons.tune), label: const Text('Adjust')),
      ]),
    ])));
  }

  Widget _moneyButton(String label, int amount, Map<String, dynamic> player) => FilledButton.tonal(onPressed: () => _changeBalance(player, amount), child: Text(label));

  Future<void> _changeBalance(Map<String, dynamic> p, int amount) async => _changeBalanceWithReason(p, amount, 'Admin ${amount > 0 ? 'credit' : 'debit'}');

  Future<void> _customBalance(Map<String, dynamic> p) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Admin adjustment');
    var add = true;
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(
      title: Text('Adjust ${p['display_name'] ?? 'player'} balance'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('Add'), icon: Icon(Icons.add)), ButtonSegment(value: false, label: Text('Remove'), icon: Icon(Icons.remove))], selected: {add}, onSelectionChanged: (v) => set(() => add = v.first)),
        const SizedBox(height: 14),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (USD)', prefixText: '\$ ')),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, {'amount': int.tryParse(amount.text.trim()), 'add': add, 'reason': reason.text.trim()}), child: const Text('Apply'))],
    )));
    amount.dispose(); reason.dispose();
    if (result == null || result['amount'] == null || (result['amount'] as int) <= 0) return;
    final value = (result['amount'] as int) * (result['add'] == true ? 1 : -1);
    await _changeBalanceWithReason(p, value, '${result['reason']}'.trim().isEmpty ? 'Admin adjustment' : '${result['reason']}');
  }

  Future<void> _changeBalanceWithReason(Map<String, dynamic> p, int amount, String reason) async => _run('Adjust balance', () => widget.repository.adminAdjustBalanceUsd(playerId: '${p['id']}', amountUsd: amount, reason: reason));

  Widget _countries() {
    final cs = rows('countries');
    return _page('Countries', [
      _addCard('Add a country', 'Enter only the country name and price.', Icons.public, _createCountry),
      for (final c in cs) Card(child: ListTile(leading: const Icon(Icons.flag), title: Text('${c['name']}'), subtitle: Text('Price: ${_money(c['base_price'])} USD'), trailing: IconButton(tooltip: 'Edit country', onPressed: () => _editCountry(c), icon: const Icon(Icons.edit)))),
      if (cs.isEmpty) const Card(child: ListTile(title: Text('No countries yet.'))),
    ]);
  }

  Future<void> _createCountry() async {
    final name = TextEditingController(); final price = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (d) => AlertDialog(
      title: const Text('Add Country'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Country name', hintText: 'Egypt')),
        TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (USD)', hintText: '5000', prefixText: '\$ ')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, {'name': name.text.trim(), 'price': int.tryParse(price.text.trim()) ?? 0}), child: const Text('Add Country'))],
    ));
    name.dispose(); price.dispose();
    if (result == null || '${result['name']}'.trim().isEmpty) return;
    await _run('Add country', () => widget.repository.adminCreateCountry(gameId: widget.gameId, name: result['name'] as String, priceUsd: result['price'] as int));
  }

  Future<void> _editCountry(Map<String, dynamic> c) async {
    final name = TextEditingController(text: '${c['name'] ?? ''}'); final price = TextEditingController(text: '${(_int(c['base_price']) / 100).round()}');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (d) => AlertDialog(title: const Text('Edit Country'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Country name')),
      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (USD)', prefixText: '\$ ')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, {'name': name.text.trim(), 'price': int.tryParse(price.text.trim()) ?? 0}), child: const Text('Save'))]));
    name.dispose(); price.dispose();
    if (result == null) return;
    await _run('Update country', () => widget.repository.adminUpdateEntity(entity: 'countries', id: '${c['id']}', patch: {'name': result['name'], 'base_price': (result['price'] as int) * 100}));
  }

  Widget _buildings() {
    final types = rows('building_types');
    return _page('Buildings', [
      _addCard('Add a building', 'Enter its name, purchase price and income.', Icons.apartment, _createBuildingType),
      for (final b in types) Card(child: ListTile(leading: const Icon(Icons.business), title: Text('${b['name']}'), subtitle: Text('Price: ${_money(b['base_cost'])} USD  •  Income: ${_money(b['base_income'])} USD/tick'), trailing: IconButton(tooltip: 'Edit building', onPressed: () => _editBuildingType(b), icon: const Icon(Icons.edit)))),
      if (types.isNotEmpty) _addCard('Install building', 'Choose a country and building type.', Icons.add_business, () => _installBuilding(types, rows('countries'))),
    ]);
  }

  Future<void> _createBuildingType() async {
    final name = TextEditingController(); final price = TextEditingController(); final income = TextEditingController(text: '0');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (d) => AlertDialog(title: const Text('Add Building'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Building name', hintText: 'Business Center')),
      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price (USD)', prefixText: '\$ ')),
      TextField(controller: income, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Income per tick (USD)', prefixText: '\$ ')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, {'name': name.text.trim(), 'price': int.tryParse(price.text.trim()) ?? 0, 'income': int.tryParse(income.text.trim()) ?? 0}), child: const Text('Add Building'))]));
    name.dispose(); price.dispose(); income.dispose();
    if (result == null || '${result['name']}'.trim().isEmpty) return;
    await _run('Add building', () => widget.repository.adminCreateBuildingType(name: result['name'] as String, priceUsd: result['price'] as int, incomeUsd: result['income'] as int));
  }

  Future<void> _editBuildingType(Map<String, dynamic> b) async {
    final name = TextEditingController(text: '${b['name'] ?? ''}'); final price = TextEditingController(text: '${(_int(b['base_cost']) / 100).round()}'); final income = TextEditingController(text: '${(_int(b['base_income']) / 100).round()}');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (d) => AlertDialog(title: const Text('Edit Building'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Building name')),
      TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Purchase price (USD)', prefixText: '\$ ')),
      TextField(controller: income, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Income per tick (USD)', prefixText: '\$ ')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, {'name': name.text.trim(), 'price': int.tryParse(price.text.trim()) ?? 0, 'income': int.tryParse(income.text.trim()) ?? 0}), child: const Text('Save'))]));
    name.dispose(); price.dispose(); income.dispose();
    if (result == null) return;
    await _run('Update building', () => widget.repository.adminUpdateEntity(entity: 'building_types', id: '${b['id']}', patch: {'name': result['name'], 'base_cost': (result['price'] as int) * 100, 'base_income': (result['income'] as int) * 100}));
  }

  Future<void> _installBuilding(List<Map<String, dynamic>> types, List<Map<String, dynamic>> countries) async {
    if (countries.isEmpty) { _snack('Add a country first.'); return; }
    String? country = '${countries.first['id']}'; int? type = _int(types.first['id']);
    final result = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(title: const Text('Install Building'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(initialValue: country, decoration: const InputDecoration(labelText: 'Country'), items: [for (final c in countries) DropdownMenuItem(value: '${c['id']}', child: Text('${c['name']}'))], onChanged: (v) => set(() => country = v)),
      DropdownButtonFormField<int>(initialValue: type, decoration: const InputDecoration(labelText: 'Building'), items: [for (final b in types) DropdownMenuItem(value: _int(b['id']), child: Text('${b['name']}'))], onChanged: (v) => set(() => type = v)),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Install'))])));
    if (result == true && country != null && type != null) await _run('Install building', () => widget.repository.adminInstallBuilding(countryId: country!, buildingTypeId: type!));
  }

  Widget _settings() => _page('Game Settings', [Card(child: ListTile(title: const Text('Game configuration'), subtitle: Text('${game['name'] ?? ''} • ${game['tick_interval_seconds'] ?? 0} seconds/tick'), trailing: FilledButton(onPressed: _editGame, child: const Text('Edit')))), for (final e in {'State': game['state'], 'Current tick': game['current_tick'], 'Tick interval': '${game['tick_interval_seconds'] ?? 0} seconds', 'Started': game['started_at'], 'Finished': game['finished_at']}.entries) Card(child: ListTile(title: Text(e.key), trailing: Text('${e.value ?? '—'}')))]);

  Future<void> _editPlayer(Map<String, dynamic> p) async {
    final name = TextEditingController(text: '${p['display_name'] ?? ''}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Edit Player'), content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final value = name.text.trim(); name.dispose();
    if (result == true) await _run('Update player', () => widget.repository.adminUpdateEntity(entity: 'players', id: '${p['id']}', patch: {'display_name': value}));
  }

  Future<void> _editGame() async {
    final name = TextEditingController(text: '${game['name'] ?? ''}'); final interval = TextEditingController(text: '${game['tick_interval_seconds'] ?? 3600}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Game Settings'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Game name')), TextField(controller: interval, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seconds per tick'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    if (result != true) { name.dispose(); interval.dispose(); return; }
    final patch = {'name': name.text.trim(), 'tick_interval_seconds': int.tryParse(interval.text.trim()) ?? 3600}; name.dispose(); interval.dispose();
    await _run('Update game settings', () => widget.repository.adminUpdateGame(widget.gameId, patch));
  }

  Widget _marketplace() => _page('Marketplace', [const Card(child: ListTile(title: Text('Marketplace management'), subtitle: Text('Listings and bids can be managed here when players create them.')))]);

  Widget _addCard(String title, String subtitle, IconData icon, VoidCallback action) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: FilledButton.icon(onPressed: action, icon: const Icon(Icons.add), label: const Text('Add'))));
  Widget _page(String title, List<Widget> children) => ListView(padding: const EdgeInsets.all(20), children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), ...children]);
  Widget _stat(String label, int value, IconData icon) => SizedBox(width: 150, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(icon), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])]))));
  Widget _action(String label, IconData icon, Future<dynamic> Function() action) => ListTile(leading: Icon(icon), title: Text(label), trailing: FilledButton(onPressed: () => _run(label, action), child: const Text('Run')));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Logout?'), content: const Text('You can sign in with another player account afterward.'), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Logout'))]));
    if (ok == true) await Supabase.instance.client.auth.signOut();
  }

  Future<void> _editListing(Map<String, dynamic> l) async {}
  Future<void> _editBid(Map<String, dynamic> b) async {}

  Future<void> _run(String label, Future<dynamic> Function() action) async {
    try { await widget.guard.run('admin:${widget.gameId}:$label', action); await load(); await widget.onChanged(); if (mounted) _snack('$label completed.'); }
    catch (e) { if (mounted) _snack('$e'); }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  int _walletCents(List<Map<String, dynamic>> ws, dynamic playerId) => _int(ws.where((w) => '${w['player_id']}' == '$playerId' && w['currency'] == 'USD').firstOrNull?['balance']);
  String _money(dynamic cents) => (_int(cents) / 100).toStringAsFixed(0);
  String _initial(dynamic value) { final s = '${value ?? 'P'}'.trim(); return s.isEmpty ? 'P' : s.substring(0, 1).toUpperCase(); }
}
