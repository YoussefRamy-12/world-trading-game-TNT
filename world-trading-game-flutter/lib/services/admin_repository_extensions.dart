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

  Future<String> adminCreateCountry({required String gameId, required String name, String? code, int population = 0}) async {
    _requireAdminAuth();
    final result = await client.rpc('admin_create_country', params: {
      'p_game': gameId,
      'p_name': name,
      'p_code': code,
      'p_population': population,
      'p_resources': <String, dynamic>{},
    });
    return result.toString();
  }

  Future<int> adminCreateBuildingType({required String slug, required String name, required int baseCost, required int baseIncome, required int maintenanceCost, required int maxLevel}) async {
    _requireAdminAuth();
    final result = await client.rpc('admin_create_building_type', params: {
      'p_slug': slug,
      'p_name': name,
      'p_base_cost': baseCost,
      'p_base_income': baseIncome,
      'p_maintenance_cost': maintenanceCost,
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
