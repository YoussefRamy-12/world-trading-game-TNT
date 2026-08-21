import 'game_repository.dart';

extension AdminRepositoryExtensions on GameRepository {
  Future<String> adminCreateGame({
    required String name,
    required String slug,
    Map<String, dynamic> config = const {},
    int tickIntervalSeconds = 3600,
    int startingBalance = 100000,
  }) async {
    _requireAdminAuth();
    final mergedConfig = {...config, 'starting_balance': startingBalance};
    final result = await client.rpc('admin_create_game', params: {
      'p_name': name,
      'p_slug': slug,
      'p_config': mergedConfig,
      'p_tick_interval_seconds': tickIntervalSeconds,
    });
    return result.toString();
  }

  Future<String> adminCreateCountry({
    required String gameId,
    required String name,
    int priceUsd = 0,
  }) async {
    _requireAdminAuth();
    final result = await client.rpc('admin_create_country', params: {
      'p_game': gameId,
      'p_name': name,
      'p_code': null,
      'p_population': 0,
      'p_resources': <String, dynamic>{},
      'p_base_price': priceUsd * 100,
    });
    return result.toString();
  }

  Future<int> adminCreateBuildingType({
    required String name,
    required int priceUsd,
    required int incomeUsd,
    int maintenanceUsd = 0,
    int maxLevel = 1,
  }) async {
    _requireAdminAuth();
    final slug = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}-${DateTime.now().millisecondsSinceEpoch}';
    final result = await client.rpc('admin_create_building_type', params: {
      'p_slug': slug,
      'p_name': name,
      'p_base_cost': priceUsd * 100,
      'p_base_income': incomeUsd * 100,
      'p_maintenance_cost': maintenanceUsd * 100,
      'p_max_level': maxLevel,
    });
    return result is num ? result.toInt() : int.parse(result.toString());
  }

  Future<String> adminInstallBuilding({required String countryId, required int buildingTypeId, int level = 1, int count = 1}) async {
    _requireAdminAuth();
    final result = await client.rpc('admin_install_building', params: {
      'p_country': countryId,
      'p_building_type': buildingTypeId,
      'p_level': level,
      'p_count': count,
    });
    return result.toString();
  }

  Future<void> adminAdjustBalanceUsd({required String playerId, required int amountUsd, String reason = 'Admin adjustment'}) async {
    _requireAdminAuth();
    await client.rpc('admin_adjust_balance', params: {
      'p_player': playerId,
      'p_amount': amountUsd * 100,
      'p_currency': 'USD',
      'p_reason': reason,
    });
  }

  Future<void> bootstrapFirstAdmin() async {
    _requireAdminAuth();
    await client.rpc('bootstrap_first_admin');
  }

  Future<bool> hasAnyAdmin() async {
    final result = await client.rpc('has_any_admin');
    return result == true;
  }

  void _requireAdminAuth() {
    if (client.auth.currentUser == null) throw StateError('You must be signed in to perform this action.');
  }
}
