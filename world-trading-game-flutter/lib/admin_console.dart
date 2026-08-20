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
  void initState() { super.initState(); load(); }

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

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(appBar: AppBar(title: const Text('Admin Console')), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('Retry'))])));
    final pages = [_overview(), _players(), _countries(), _buildings(), _settings(), _marketplace()];
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Console'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
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
    final ps = rows('players');
    final cs = rows('countries');
    final bs = rows('country_buildings');
    final ws = rows('wallets');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: Text('${game['name'] ?? 'Game'} administration'), subtitle: Text('State: ${game['state'] ?? ''} • Tick ${game['current_tick'] ?? 0}'))),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, c) => GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 2 : 1, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5, children: [_stat('Players', ps.length, Icons.people), _stat('Countries', cs.length, Icons.public), _stat('Buildings', bs.length, Icons.apartment), _stat('Wallets', ws.length, Icons.account_balance_wallet)])),
      const SizedBox(height: 16),
      _section('Game lifecycle', [
        _action('Ready', Icons.check_circle_outline, () => widget.repository.setGameReady(widget.gameId)),
        _action('Start', Icons.play_arrow, () => widget.repository.startGame(widget.gameId)),
        _action('Pause', Icons.pause, () => widget.repository.pauseGame(widget.gameId)),
        _action('Resume', Icons.play_circle, () => widget.repository.resumeGame(widget.gameId)),
        _action('Manual tick', Icons.timelapse, () => widget.repository.advanceTick(widget.gameId)),
        _action('Finish', Icons.flag, () => widget.repository.finishGame(widget.gameId)),
      ]),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('All management operations go through admin-only server RPCs. Players cannot modify these values from the client.'))),
    ]);
  }

  Widget _players() {
    final ps = rows('players');
    final ws = rows('wallets');
    return _page('Players', [for (final p in ps) Card(child: ListTile(
      leading: CircleAvatar(child: Text(_initial(p['display_name']))),
      title: Text('${p['display_name'] ?? 'Unnamed'}${p['is_admin'] == true ? ' • ADMIN' : ''}'),
      subtitle: Text('Balance: ${_wallet(ws, p['id'])} USD\n${p['id']}'),
      isThreeLine: true,
      trailing: Wrap(children: [IconButton(onPressed: () => _editPlayer(p), icon: const Icon(Icons.edit)), IconButton(onPressed: () => _balance(p), icon: const Icon(Icons.account_balance_wallet))]),
    )), if (ps.isEmpty) const Card(child: ListTile(title: Text('No players.')))]);
  }

  Widget _countries() {
    final cs = rows('countries');
    final ps = rows('players');
    return _page('Countries', [for (final c in cs) Card(child: ListTile(
      leading: const Icon(Icons.flag), title: Text('${c['name']} ${c['code'] == null ? '' : '(${c['code']})'}'),
      subtitle: Text('Population: ${c['population'] ?? 0}\nOwner: ${_name(ps, c['owner_player_id'])}'), isThreeLine: true,
      trailing: IconButton(onPressed: () => _editCountry(c, ps), icon: const Icon(Icons.edit)),
    )), if (cs.isEmpty) const Card(child: ListTile(title: Text('No countries.')))]);
  }

  Widget _buildings() {
    final types = rows('building_types');
    final installed = rows('country_buildings');
    final countries = rows('countries');
    return _page('Buildings', [
      Card(child: ExpansionTile(title: Text('Building catalog (${types.length})'), children: [for (final b in types) ListTile(title: Text('${b['name']} (#${b['id']})'), subtitle: Text('Cost ${b['base_cost']} • Income ${b['base_income']} • Maintenance ${b['maintenance_cost']} • Max ${b['max_level']}'), trailing: IconButton(onPressed: () => _editBuildingType(b), icon: const Icon(Icons.edit)))])),
      Card(child: ExpansionTile(title: Text('Installed buildings (${installed.length})'), children: [for (final b in installed) ListTile(title: Text(_buildingName(b, types)), subtitle: Text('${_country(countries, b['country_id'])} • Level ${b['level']} • Count ${b['count']}'), trailing: IconButton(onPressed: () => _editInstalled(b, types), icon: const Icon(Icons.edit)))])),
    ]);
  }

  Widget _settings() => _page('Game settings', [
    Card(child: ListTile(title: const Text('Edit simulation settings'), subtitle: const Text('Name, slug, tick interval and current tick'), trailing: FilledButton(onPressed: _editGame, child: const Text('Edit')))),
    for (final e in {'Name': game['name'], 'Slug': game['slug'], 'State': game['state'], 'Current tick': game['current_tick'], 'Tick interval': '${game['tick_interval_seconds'] ?? 0} seconds', 'Started': game['started_at'], 'Paused': game['paused_at'], 'Finished': game['finished_at'], 'Last tick': game['last_tick_at']}.entries) Card(child: ListTile(title: Text(e.key), trailing: Text('${e.value ?? '—'}'))),
  ]);

  Widget _marketplace() {
    final ls = rows('listings');
    final bs = rows('bids');
    final cs = rows('countries');
    final ps = rows('players');
    return _page('Marketplace', [
      Card(child: ExpansionTile(title: Text('Listings (${ls.length})'), children: [for (final l in ls) ListTile(title: Text('${_country(cs, l['country_id'])} • ${l['price']} ${l['currency']}'), subtitle: Text('${_name(ps, l['seller_player_id'])} • ${l['status']}'), trailing: IconButton(onPressed: () => _editListing(l), icon: const Icon(Icons.edit)))])),
      Card(child: ExpansionTile(title: Text('Bids (${bs.length})'), children: [for (final b in bs) ListTile(title: Text('${b['amount']} ${b['currency']}'), subtitle: Text('${_name(ps, b['bidder_player_id'])} • ${b['status']}'), trailing: IconButton(onPressed: () => _editBid(b), icon: const Icon(Icons.edit)))])),
    ]);
  }

  Widget _page(String title, List<Widget> children) => ListView(padding: const EdgeInsets.all(20), children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), ...children]);
  Widget _stat(String label, int value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))])));
  Widget _section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ...children])));
  Widget _action(String label, IconData icon, Future<dynamic> Function() action) => ListTile(leading: Icon(icon), title: Text(label), trailing: FilledButton(onPressed: () => _run(label, action), child: const Text('Run')));

  Future<void> _editPlayer(Map<String, dynamic> p) async {
    final name = TextEditingController(text: '${p['display_name'] ?? ''}');
    final avatar = TextEditingController(text: '${p['avatar_url'] ?? ''}');
    var admin = p['is_admin'] == true;
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(title: const Text('Edit player'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')), TextField(controller: avatar, decoration: const InputDecoration(labelText: 'Avatar URL')), SwitchListTile(title: const Text('Admin'), value: admin, onChanged: (v) => set(() => admin = v))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))])));
    if (ok != true) { name.dispose(); avatar.dispose(); return; }
    final patch = {'display_name': name.text.trim(), 'avatar_url': avatar.text.trim(), 'is_admin': admin};
    name.dispose(); avatar.dispose();
    await _run('Update player', () => widget.repository.adminUpdateEntity(entity: 'players', id: '${p['id']}', patch: patch));
  }

  Future<void> _balance(Map<String, dynamic> p) async {
    final amount = TextEditingController();
    final reason = TextEditingController(text: 'Admin adjustment');
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('Balance: ${p['display_name'] ?? 'player'}'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', helperText: 'Negative removes balance')), TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Apply'))]));
    if (ok != true) { amount.dispose(); reason.dispose(); return; }
    final value = int.tryParse(amount.text.trim());
    final why = reason.text.trim();
    amount.dispose(); reason.dispose();
    if (value == null || value == 0) return;
    await _run('Adjust balance', () => widget.repository.adminAdjustBalance(playerId: '${p['id']}', amount: value, reason: why.isEmpty ? 'Admin adjustment' : why));
  }

  Future<void> _editCountry(Map<String, dynamic> c, List<Map<String, dynamic>> players) async {
    final name = TextEditingController(text: '${c['name'] ?? ''}');
    final code = TextEditingController(text: '${c['code'] ?? ''}');
    final pop = TextEditingController(text: '${c['population'] ?? 0}');
    String? owner = c['owner_player_id']?.toString();
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(title: Text('Edit ${c['name']}'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')), TextField(controller: pop, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Population')), DropdownButtonFormField<String?>(value: owner, decoration: const InputDecoration(labelText: 'Owner'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Unowned')), ...players.map((p) => DropdownMenuItem<String?>(value: '${p['id']}', child: Text('${p['display_name'] ?? 'Player'}')))], onChanged: (v) => set(() => owner = v))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))])));
    if (ok != true) { name.dispose(); code.dispose(); pop.dispose(); return; }
    final patch = {'name': name.text.trim(), 'code': code.text.trim(), 'population': int.tryParse(pop.text.trim()) ?? 0, 'owner_player_id': owner};
    name.dispose(); code.dispose(); pop.dispose();
    await _run('Update country', () => widget.repository.adminUpdateEntity(entity: 'countries', id: '${c['id']}', patch: patch));
  }

  Future<void> _editBuildingType(Map<String, dynamic> b) async {
    final name = TextEditingController(text: '${b['name']}');
    final slug = TextEditingController(text: '${b['slug']}');
    final cost = TextEditingController(text: '${b['base_cost'] ?? 0}');
    final income = TextEditingController(text: '${b['base_income'] ?? 0}');
    final maintenance = TextEditingController(text: '${b['maintenance_cost'] ?? 0}');
    final max = TextEditingController(text: '${b['max_level'] ?? 1}');
    final ok = await _form('Edit building type', [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')), _num(cost, 'Base cost'), _num(income, 'Income per tick'), _num(maintenance, 'Maintenance per tick'), _num(max, 'Max level')]);
    if (ok != true) { name.dispose(); slug.dispose(); cost.dispose(); income.dispose(); maintenance.dispose(); max.dispose(); return; }
    final patch = {'name': name.text.trim(), 'slug': slug.text.trim(), 'base_cost': int.tryParse(cost.text) ?? 0, 'base_income': int.tryParse(income.text) ?? 0, 'maintenance_cost': int.tryParse(maintenance.text) ?? 0, 'max_level': int.tryParse(max.text) ?? 1};
    name.dispose(); slug.dispose(); cost.dispose(); income.dispose(); maintenance.dispose(); max.dispose();
    await _run('Update building type', () => widget.repository.adminUpdateEntity(entity: 'building_types', id: '${b['id']}', patch: patch));
  }

  Future<void> _editInstalled(Map<String, dynamic> b, List<Map<String, dynamic>> types) async {
    final level = TextEditingController(text: '${b['level'] ?? 1}');
    final count = TextEditingController(text: '${b['count'] ?? 1}');
    int? type = int.tryParse('${b['building_type_id']}');
    final ok = await showDialog<bool>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(title: const Text('Edit installed building'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<int>(value: type, decoration: const InputDecoration(labelText: 'Building type'), items: [for (final t in types) DropdownMenuItem(value: int.tryParse('${t['id']}'), child: Text('${t['name']}'))], onChanged: (v) => set(() => type = v)), _num(level, 'Level'), _num(count, 'Count')]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))])));
    if (ok != true || type == null) { level.dispose(); count.dispose(); return; }
    final patch = {'building_type_id': type, 'level': int.tryParse(level.text) ?? 1, 'count': int.tryParse(count.text) ?? 1};
    level.dispose(); count.dispose();
    await _run('Update installed building', () => widget.repository.adminUpdateEntity(entity: 'country_buildings', id: '${b['id']}', patch: patch));
  }

  Future<void> _editGame() async {
    final name = TextEditingController(text: '${game['name'] ?? ''}');
    final slug = TextEditingController(text: '${game['slug'] ?? ''}');
    final interval = TextEditingController(text: '${game['tick_interval_seconds'] ?? 3600}');
    final tick = TextEditingController(text: '${game['current_tick'] ?? 0}');
    final ok = await _form('Edit game settings', [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')), _num(interval, 'Tick interval seconds'), _num(tick, 'Current tick')]);
    if (ok != true) { name.dispose(); slug.dispose(); interval.dispose(); tick.dispose(); return; }
    final patch = {'name': name.text.trim(), 'slug': slug.text.trim(), 'tick_interval_seconds': int.tryParse(interval.text) ?? 3600, 'current_tick': int.tryParse(tick.text) ?? 0};
    name.dispose(); slug.dispose(); interval.dispose(); tick.dispose();
    await _run('Update game settings', () => widget.repository.adminUpdateGame(widget.gameId, patch));
  }

  Future<void> _editListing(Map<String, dynamic> l) async {
    final price = TextEditingController(text: '${l['price'] ?? 0}');
    final status = TextEditingController(text: '${l['status'] ?? 'open'}');
    final ok = await _form('Edit listing', [TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')), TextField(controller: status, decoration: const InputDecoration(labelText: 'Status'))]);
    if (ok != true) { price.dispose(); status.dispose(); return; }
    final patch = {'price': int.tryParse(price.text) ?? 1, 'status': status.text.trim()};
    price.dispose(); status.dispose();
    await _run('Update listing', () => widget.repository.adminUpdateEntity(entity: 'country_listings', id: '${l['id']}', patch: patch));
  }

  Future<void> _editBid(Map<String, dynamic> b) async {
    final amount = TextEditingController(text: '${b['amount'] ?? 0}');
    final status = TextEditingController(text: '${b['status'] ?? 'pending'}');
    final ok = await _form('Edit bid', [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')), TextField(controller: status, decoration: const InputDecoration(labelText: 'Status'))]);
    if (ok != true) { amount.dispose(); status.dispose(); return; }
    final patch = {'amount': int.tryParse(amount.text) ?? 1, 'status': status.text.trim()};
    amount.dispose(); status.dispose();
    await _run('Update bid', () => widget.repository.adminUpdateEntity(entity: 'bids', id: '${b['id']}', patch: patch));
  }

  Future<bool?> _form(String title, List<Widget> fields) => showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text(title), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
  Widget _num(TextEditingController c, String label) => TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));

  Future<void> _run(String label, Future<void> Function() action) async {
    try { await widget.guard.run('admin:${widget.gameId}:$label', action); await load(); await widget.onChanged(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label completed.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  String _initial(dynamic value) { final s = '${value ?? 'P'}'.trim(); return s.isEmpty ? 'P' : s.substring(0, 1).toUpperCase(); }
  String _name(List<Map<String, dynamic>> ps, dynamic id) => ps.where((p) => '${p['id']}' == '$id').firstOrNull?['display_name']?.toString() ?? 'Unowned';
  String _country(List<Map<String, dynamic>> cs, dynamic id) => cs.where((c) => '${c['id']}' == '$id').firstOrNull?['name']?.toString() ?? 'Country';
  String _buildingName(Map<String, dynamic> b, List<Map<String, dynamic>> types) => types.where((t) => '${t['id']}' == '${b['building_type_id']}').firstOrNull?['name']?.toString() ?? 'Building';
  dynamic _wallet(List<Map<String, dynamic>> ws, dynamic playerId) => ws.where((w) => '${w['player_id']}' == '$playerId' && w['currency'] == 'USD').firstOrNull?['balance'] ?? 0;
}
