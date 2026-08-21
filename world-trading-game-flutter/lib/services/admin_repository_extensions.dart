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
    final mergedConfig = {
      ...config,
      'starting_balance': startingBalance,
    };
    final result = await client.rpc('admin_create_game', params: {
      'p_name': name,
      'p_slug': slug,
      'p_config': mergedConfig,
      'p_tick_interval_seconds': tickIntervalSeconds,
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
    if (client.auth.currentUser == null) {
      throw StateError('You must be signed in to perform this action.');
    }
  }
}
