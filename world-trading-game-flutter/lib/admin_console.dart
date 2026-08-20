import 'package:flutter/material.dart';

import 'services/action_guard.dart';
import 'services/game_repository.dart';

class AdminConsolePage extends StatefulWidget {
  final String gameId;
  final GameRepository repository;
  final ActionGuard guard;
  final Future<void> Function() onChanged;

  const AdminConsolePage({super.key, required this.gameId, required this.repository, required this.guard, required this.onChanged});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.repository.fetchAdminGameData(widget.gameId);
      if (mounted) setState(() { data = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  List<Map<String, dynamic>> _rows(String key) => ((data[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Map<String, dynamic> get game => Map<String, dynamic>.from((data['game'] as Map?) ?? const {});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(appBar: AppBar(title: const Text('Admin Console')), body: _error(context));
    final pages = [
      _overview(context),
      _players(context),
      _countries(context),
      _buildings(context),
      _settings(context),
      _marketplace(context),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Console'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'Refresh all data')]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Players'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Countries'),
          NavigationDestination(icon: Icon(Icons.apartment), label: 'Buildings'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Market'),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 48), const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: load, child: const Text('Retry')),
  ])));

  Widget _overview(BuildContext context) {
    final players = _rows('players');
    final countries = _rows('countries');
    final buildings = _rows('country_buildings');
    final wallets = _rows('wallets');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: Text('${game['name'] ?? 'Game'} administration'), subtitle: Text('State: ${(game['state'] ?? '').toString().toUpperCase()} • Tick ${game['current_tick'] ?? 0}'))),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth >= 850 ? 4 : c.maxWidth >= 520 ? 2 : 1;
        return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.3, children: [
          _stat('Players', '${players.length}', Icons.people), _stat('Countries', '${countries.length}', Icons.public), _stat('Installed buildings', '${buildings.length}', Icons.apartment), _stat('Wallets', '${wallets.length}', Icons.account_balance_wallet),
        ]);
      }),
      const SizedBox(height: 20),
      _sectionCard('Game lifecycle', [
        _action(context, 'Ready', Icons.check_circle_outline, () => widget.repository.setGameReady(widget.gameId)),
        _action(context, 'Start', Icons.play_arrow, () => widget.repository.startGame(widget.gameId)),
        _action(context, 'Pause', Icons.pause, () => widget.repository.pauseGame(widget.gameId)),
        _action(context, 'Resume', Icons.play_circle, () => widget.repository.resumeGame(widget.gameId)),
        _action(context, 'Manual tick', Icons.timelapse, () => widget.repository.advanceTick(widget.gameId)),
        _action(context, 'Finish', Icons.flag, () => widget.repository.finishGame(widget.gameId)),
      ]),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('This console is server-authorized. Every edit is performed through an admin-only RPC, so a normal player cannot modify game data by calling the client directly.'))),
    ]);
  }

  Widget _players(BuildContext context) {
    final players = _rows('players');
    final wallets = _rows('wallets');
    return _listPage(context, title: 'Players', children: [
      for (final p in players) _playerCard(context, p, wallets.where((w) => w['player_id']?.toString() == p['id']?.toString()).toList()),
      if (players.isEmpty) const Card(child: ListTile(title: Text('No players in this game.'))),
    ]);
  }

  Widget _playerCard(BuildContext context, Map<String, dynamic> p, List<Map<String, dynamic>> walletRows) {
    final balance = walletRows.where((w) => w['currency'] == 'USD').firstOrNull?['balance'] ?? 0;
    return Card(child: ListTile(
      leading: CircleAvatar(child: Text((p['display_name'] ?? 'P').toString().characters.first.toUpperCase())),
      title: Text('${p['display_name'] ?? 'Unnamed player'}${p['is_admin'] == true ? ' • ADMIN' : ''}'),
      subtitle: Text('ID: ${p['id']}\nBalance: $balance USD'),
      isThreeLine: true,
      trailing: Wrap(spacing: 4, children: [
        IconButton(tooltip: 'Edit player', onPressed: () => _editPlayer(context, p), icon: const Icon(Icons.edit)),
        IconButton(tooltip: 'Add / remove balance', onPressed: () => _adjustBalance(context, p), icon: const Icon(Icons.account_balance_wallet)),
      ]),
    ));
  }

  Widget _countries(BuildContext context) {
    final countries = _rows('countries');
    final players = _rows('players');
    return _listPage(context, title: 'Countries', children: [
      for (final c in countries) Card(child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text('${c['name'] ?? 'Country'} ${c['code'] == null ? '' : '(${c['code']})'}'),
        subtitle: Text('Population: ${c['population'] ?? 0}\nOwner: ${_playerName(players, c['owner_player_id'])}'),
        isThreeLine: true,
        trailing: IconButton(onPressed: () => _editCountry(context, c, players), icon: const Icon(Icons.edit), tooltip: 'Edit country'),
      )),
      if (countries.isEmpty) const Card(child: ListTile(title: Text('No countries in this game.'))),
    ]);
  }

  Widget _buildings(BuildContext context) {
    final types = _rows('building_types');
    final installed = _rows('country_buildings');
    final countries = _rows('countries');
    return _listPage(context, title: 'Buildings', children: [
      Card(child: ExpansionTile(title: const Text('Building catalog'), children: [
        for (final b in types) ListTile(title: Text('${b['name']} (#${b['id']})'), subtitle: Text('Cost ${b['base_cost']} • Income ${b['base_income']} • Max level ${b['max_level']}'), trailing: IconButton(onPressed: () => _editBuildingType(context, b), icon: const Icon(Icons.edit))),
      ])),
      const SizedBox(height: 8),
      Card(child: ExpansionTile(title: const Text('Installed buildings'), children: [
        for (final b in installed) ListTile(title: Text(_buildingLabel(b, types)), subtitle: Text('Country: ${_countryName(countries, b['country_id'])} • Level ${b['level']} • Count ${b['count']}'), trailing: IconButton(onPressed: () => _editInstalledBuilding(context, b, types), icon: const Icon(Icons.edit))),
      ])),
    ]);
  }

  Widget _settings(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: ListTile(title: const Text('Game settings'), subtitle: const Text('The admin controls the values that drive the simulation.'), trailing: FilledButton.icon(onPressed: () => _editGame(context), icon: const Icon(Icons.edit), label: const Text('Edit')))),
      const SizedBox(height: 12),
      _valueTile('Name', game['name']), _valueTile('Slug', game['slug']), _valueTile('State', game['state']), _valueTile('Current tick', game['current_tick']), _valueTile('Tick interval', '${game['tick_interval_seconds'] ?? 0} seconds'), _valueTile('Started', game['started_at']), _valueTile('Paused', game['paused_at']), _valueTile('Finished', game['finished_at']), _valueTile('Last tick', game['last_tick_at']),
    ]);
  }

  Widget _marketplace(BuildContext context) {
    final listings = _rows('listings');
    final bids = _rows('bids');
    final countries = _rows('countries');
    final players = _rows('players');
    return _listPage(context, title: 'Marketplace', children: [
      Card(child: ExpansionTile(title: Text('Listings (${listings.length})'), children: [
        for (final l in listings) ListTile(title: Text('${_countryName(countries, l['country_id'])} • ${l['price']} ${l['currency']}'), subtitle: Text('Seller: ${_playerName(players, l['seller_player_id'])} • ${l['status']}'), trailing: IconButton(onPressed: () => _editListing(context, l), icon: const Icon(Icons.edit))),
      ])),
      Card(child: ExpansionTile(title: Text('Bids (${bids.length})'), children: [
        for (final b in bids) ListTile(title: Text('${b['amount']} ${b['currency']}'), subtitle: Text('Bidder: ${_playerName(players, b['bidder_player_id'])} • ${b['status']}'), trailing: IconButton(onPressed: () => _editBid(context, b), icon: const Icon(Icons.edit))),
      ])),
    ]);
  }

  Widget _listPage(BuildContext context, {required String title, required List<Widget> children}) => ListView(padding: const EdgeInsets.all(20), children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), ...children]);
  Widget _stat(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]))])));
  Widget _sectionCard(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(4), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), ...children])));
  Widget _valueTile(String label, dynamic value) => Card(child: ListTile(title: Text(label), trailing: Text('${value ?? '—'}')));

  Widget _action(BuildContext context, String label, IconData icon, Future<dynamic> Function() action) => ListTile(leading: Icon(icon), title: Text(label), trailing: FilledButton(onPressed: () async { try { await widget.guard.run('admin:${widget.gameId}:$label', action); await load(); await widget.onChanged(); _ok(context, '$label completed.'); } catch (e) { _errorSnack(context, e); } }, child: const Text('Run')));

  Future<void> _editPlayer(BuildContext context, Map<String, dynamic> p) async {
    final name = TextEditingController(text: '${p['display_name'] ?? ''}');
    final avatar = TextEditingController(text: '${p['avatar_url'] ?? ''}');
    bool isAdmin = p['is_admin'] == true;
    final result = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (context, set) => AlertDialog(title: const Text('Edit player'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')), TextField(controller: avatar, decoration: const InputDecoration(labelText: 'Avatar URL')), SwitchListTile(title: const Text('Admin'), value: isAdmin, onChanged: (v) => set(() => isAdmin = v))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))])));
    name.dispose(); avatar.dispose();
    if (result != true) return;
    await _run(context, 'Update player', () => widget.repository.adminUpdateEntity(entity: 'players', id: '${p['id']}', patch: {'display_name': name.text.trim(), 'avatar_url': avatar.text.trim(), 'is_admin': isAdmin}));
  }

  Future<void> _adjustBalance(BuildContext context, Map<String, dynamic> p) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Admin adjustment');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('Adjust ${p['display_name'] ?? 'player'} balance'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', helperText: 'Use a negative number to remove money.')), TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Apply'))]));
    final value = int.tryParse(amount.text.trim());
    final why = reason.text.trim(); amount.dispose(); reason.dispose();
    if (result != true || value == null || value == 0) return;
    await _run(context, 'Adjust balance', () => widget.repository.adminAdjustBalance(playerId: '${p['id']}', amount: value, reason: why.isEmpty ? 'Admin adjustment' : why));
  }

  Future<void> _editCountry(BuildContext context, Map<String, dynamic> c, List<Map<String, dynamic>> players) async {
    final name = TextEditingController(text: '${c['name'] ?? ''}');
    final code = TextEditingController(text: '${c['code'] ?? ''}');
    final population = TextEditingController(text: '${c['population'] ?? 0}');
    String? owner = c['owner_player_id']?.toString();
    final result = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (context, set) => AlertDialog(title: Text('Edit ${c['name'] ?? 'country'}'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')), TextField(controller: population, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Population')), DropdownButtonFormField<String?>(value: owner, decoration: const InputDecoration(labelText: 'Owner'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Unowned')), ...players.map((p) => DropdownMenuItem<String?>(value: p['id']?.toString(), child: Text('${p['display_name'] ?? 'Player'}')))], onChanged: (v) => set(() => owner = v))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))])));
    final patch = {'name': name.text.trim(), 'code': code.text.trim(), 'population': int.tryParse(population.text.trim()) ?? 0, 'owner_player_id': owner};
    name.dispose(); code.dispose(); population.dispose();
    if (result != true) return;
    await _run(context, 'Update country', () => widget.repository.adminUpdateEntity(entity: 'countries', id: '${c['id']}', patch: patch));
  }

  Future<void> _editBuildingType(BuildContext context, Map<String, dynamic> b) async {
    final name = TextEditingController(text: '${b['name'] ?? ''}');
    final slug = TextEditingController(text: '${b['slug'] ?? ''}');
    final cost = TextEditingController(text: '${b['base_cost'] ?? 0}');
    final income = TextEditingController(text: '${b['base_income'] ?? 0}');
    final maintenance = TextEditingController(text: '${b['maintenance_cost'] ?? 0}');
    final max = TextEditingController(text: '${b['max_level'] ?? 1}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('Edit ${b['name'] ?? 'building'}'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')), _numField(cost, 'Base cost'), _numField(income, 'Base income per tick'), _numField(maintenance, 'Maintenance per tick'), _numField(max, 'Max level') ])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final patch = {'name': name.text.trim(), 'slug': slug.text.trim(), 'base_cost': int.tryParse(cost.text.trim()) ?? 0, 'base_income': int.tryParse(income.text.trim()) ?? 0, 'maintenance_cost': int.tryParse(maintenance.text.trim()) ?? 0, 'max_level': int.tryParse(max.text.trim()) ?? 1};
    name.dispose(); slug.dispose(); cost.dispose(); income.dispose(); maintenance.dispose(); max.dispose();
    if (result != true) return;
    await _run(context, 'Update building type', () => widget.repository.adminUpdateEntity(entity: 'building_types', id: '${b['id']}', patch: patch));
  }

  Future<void> _editInstalledBuilding(BuildContext context, Map<String, dynamic> b, List<Map<String, dynamic>> types) async {
    final level = TextEditingController(text: '${b['level'] ?? 1}');
    final count = TextEditingController(text: '${b['count'] ?? 1}');
    int? type = int.tryParse('${b['building_type_id']}');
    final result = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (context, set) => AlertDialog(title: const Text('Edit installed building'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<int>(value: type, decoration: const InputDecoration(labelText: 'Building type'), items: [for (final t in types) DropdownMenuItem(value: int.tryParse('${t['id']}'), child: Text('${t['name']}'))], onChanged: (v) => set(() => type = v)), _numField(level, 'Level'), _numField(count, 'Count')]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final patch = {'building_type_id': type, 'level': int.tryParse(level.text.trim()) ?? 1, 'count': int.tryParse(count.text.trim()) ?? 1};
    level.dispose(); count.dispose();
    if (result != true || type == null) return;
    await _run(context, 'Update installed building', () => widget.repository.adminUpdateEntity(entity: 'country_buildings', id: '${b['id']}', patch: patch));
  }

  Future<void> _editGame(BuildContext context) async {
    final name = TextEditingController(text: '${game['name'] ?? ''}');
    final slug = TextEditingController(text: '${game['slug'] ?? ''}');
    final interval = TextEditingController(text: '${game['tick_interval_seconds'] ?? 3600}');
    final tick = TextEditingController(text: '${game['current_tick'] ?? 0}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Edit game settings'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Game name')), TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')), _numField(interval, 'Tick interval (seconds)'), _numField(tick, 'Current tick')]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final patch = {'name': name.text.trim(), 'slug': slug.text.trim(), 'tick_interval_seconds': int.tryParse(interval.text.trim()) ?? 3600, 'current_tick': int.tryParse(tick.text.trim()) ?? 0};
    name.dispose(); slug.dispose(); interval.dispose(); tick.dispose();
    if (result != true) return;
    await _run(context, 'Update game settings', () => widget.repository.adminUpdateGame(widget.gameId, patch));
  }

  Future<void> _editListing(BuildContext context, Map<String, dynamic> l) async {
    final price = TextEditingController(text: '${l['price'] ?? 0}');
    final status = TextEditingController(text: '${l['status'] ?? 'open'}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Edit listing'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')), TextField(controller: status, decoration: const InputDecoration(labelText: 'Status'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final patch = {'price': int.tryParse(price.text.trim()) ?? 0, 'status': status.text.trim()}; price.dispose(); status.dispose();
    if (result != true) return;
    await _run(context, 'Update listing', () => widget.repository.adminUpdateEntity(entity: 'country_listings', id: '${l['id']}', patch: patch));
  }

  Future<void> _editBid(BuildContext context, Map<String, dynamic> b) async {
    final amount = TextEditingController(text: '${b['amount'] ?? 0}');
    final status = TextEditingController(text: '${b['status'] ?? 'pending'}');
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Edit bid'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')), TextField(controller: status, decoration: const InputDecoration(labelText: 'Status'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    final patch = {'amount': int.tryParse(amount.text.trim()) ?? 0, 'status': status.text.trim()}; amount.dispose(); status.dispose();
    if (result != true) return;
    await _run(context, 'Update bid', () => widget.repository.adminUpdateEntity(entity: 'bids', id: '${b['id']}', patch: patch));
  }

  Future<void> _run(BuildContext context, String label, Future<void> Function() action) async {
    try { await widget.guard.run('admin:${widget.gameId}:$label', action); await load(); await widget.onChanged(); _ok(context, '$label completed.'); } catch (e) { _errorSnack(context, e); }
  }

  void _ok(BuildContext context, String text) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  void _errorSnack(BuildContext context, Object e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  Widget _numField(TextEditingController c, String label) => TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));
  String _playerName(List<Map<String, dynamic>> players, dynamic id) => players.where((p) => p['id']?.toString() == id?.toString()).firstOrNull?['display_name']?.toString() ?? 'Unowned';
  String _countryName(List<Map<String, dynamic>> countries, dynamic id) => countries.where((c) => c['id']?.toString() == id?.toString()).firstOrNull?['name']?.toString() ?? 'Country';
  String _buildingLabel(Map<String, dynamic> b, List<Map<String, dynamic>> types) => types.where((t) => '${t['id']}' == '${b['building_type_id']}').firstOrNull?['name']?.toString() ?? 'Building #${b['building_type_id']}';
}
