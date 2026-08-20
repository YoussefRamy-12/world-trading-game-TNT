import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building.dart';
import '../models/country.dart';
import '../models/game.dart';
import '../models/marketplace.dart';
import '../models/player.dart';

class GameRepository {
  final SupabaseClient client;

  GameRepository({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  Future<List<Game>> fetchGames() async {
    final rows = await client.from('games').select().order('created_at');
    return (rows as List).map((r) => Game.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<Game?> fetchGame(String gameId) async {
    final row = await client.from('games').select().eq('id', gameId).maybeSingle();
    return row == null ? null : Game.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Player?> fetchCurrentPlayer() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await client.from('players').select().eq('user_id', userId).maybeSingle();
    return row == null ? null : Player.fromMap(Map<String, dynamic>.from(row));
  }

  Future<int?> fetchWalletBalance(String playerId, {String currency = 'USD'}) async {
    final row = await client.from('wallets').select('balance').eq('player_id', playerId).eq('currency', currency).maybeSingle();
    if (row == null) return null;
    final value = row['balance'];
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  Future<String> registerPlayer({String? displayName, String? avatarUrl}) async {
    _requireAuth();
    final result = await client.rpc('register_player', params: {
      'p_display_name': displayName,
      'p_avatar_url': avatarUrl,
    });
    return result.toString();
  }

  Future<String> joinGame(String gameId) async {
    _requireAuth();
    final result = await client.rpc('join_game', params: {'p_game': gameId});
    return result.toString();
  }

  Future<List<Country>> fetchCountries({String? gameId, bool publicOnly = false}) async {
    var query = client.from('countries').select('id, game_id, name, code, population, resources, owner_player_id, metadata');
    if (gameId != null) query = query.eq('game_id', gameId);
    if (publicOnly) query = query.eq('metadata->>public', 'true');
    final rows = await query.order('name');
    return (rows as List).map((r) => Country.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<Country>> fetchPublicCountriesWithValues({String? gameId}) async {
    final countries = await fetchCountries(gameId: gameId, publicOnly: true);
    final result = <Country>[];
    for (final country in countries) {
      final value = await client.rpc('country_value', params: {'p_country': country.id});
      result.add(Country.fromMap({
        'id': country.id,
        'game_id': country.gameId,
        'name': country.name,
        'code': country.code,
        'population': country.population,
        'resources': country.resources,
        'owner_player_id': country.ownerPlayerId,
        'value': value,
      }));
    }
    return result;
  }

  Future<List<BuildingType>> fetchBuildingTypes() async {
    final rows = await client.from('building_types').select().order('id');
    return (rows as List).map((r) => BuildingType.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<CountryBuilding>> fetchCountryBuildings(String countryId) async {
    final rows = await client.from('country_buildings').select().eq('country_id', countryId).order('installed_at');
    return (rows as List).map((r) => CountryBuilding.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String> purchaseBuildings({required String countryId, required int buildingTypeId, int quantity = 1}) async {
    _requireAuth();
    if (quantity != 1) throw ArgumentError('A country can receive only one building per build action.');
    final result = await client.rpc('purchase_buildings', params: {
      'p_country': countryId,
      'p_building_type': buildingTypeId,
      'p_quantity': 1,
    });
    return result.toString();
  }

  Future<String> sellCountry({required String countryId, required int price, String currency = 'USD', DateTime? expiresAt}) async {
    _requireAuth();
    if (price <= 0) throw ArgumentError.value(price, 'price');
    final result = await client.rpc('sell_country', params: {
      'p_country': countryId,
      'p_price': price,
      'p_currency': currency,
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
    });
    return result.toString();
  }

  Future<List<CountryListing>> fetchListings() async {
    final rows = await client.from('country_listings').select().order('created_at', ascending: false);
    return (rows as List).map((r) => CountryListing.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String> buyCountry(String listingId) async {
    _requireAuth();
    final result = await client.rpc('buy_country', params: {'p_listing': listingId});
    return result?.toString() ?? '';
  }

  Future<String> placeBid({required String listingId, required int amount, String currency = 'USD'}) async {
    _requireAuth();
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final result = await client.rpc('place_bid', params: {'p_listing': listingId, 'p_amount': amount, 'p_currency': currency});
    return result.toString();
  }

  Future<void> cancelListing(String listingId) async {
    _requireAuth();
    await client.rpc('cancel_listing', params: {'p_listing': listingId});
  }

  Future<void> cancelBid(String bidId) async {
    _requireAuth();
    await client.rpc('cancel_bid', params: {'p_bid': bidId});
  }

  Future<void> acceptBid(String bidId) async {
    _requireAuth();
    await client.rpc('accept_bid', params: {'p_bid': bidId});
  }

  Future<void> rejectBid(String bidId) async {
    _requireAuth();
    await client.rpc('reject_bid', params: {'p_bid': bidId});
  }

  Future<void> setGameReady(String gameId) async => _lifecycle('set_game_ready', gameId);
  Future<void> startGame(String gameId) async => _lifecycle('start_game', gameId);
  Future<void> pauseGame(String gameId) async => _lifecycle('pause_game', gameId);
  Future<void> resumeGame(String gameId) async => _lifecycle('resume_game', gameId);
  Future<void> finishGame(String gameId) async => _lifecycle('finish_game', gameId);

  Future<int> advanceTick(String gameId) async {
    _requireAuth();
    final result = await client.rpc('advance_tick', params: {'p_game': gameId});
    return result is num ? result.toInt() : int.parse(result.toString());
  }

  Future<List<Map<String, dynamic>>> fetchNetWorths(String gameId) async {
    final rows = await client.rpc('compute_net_worths', params: {'p_game': gameId});
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchLatestLeaderboard(String gameId) async {
    final result = await client.rpc('get_latest_leaderboard_snapshot', params: {'p_game': gameId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> fetchAdminGameData(String gameId) async {
    _requireAuth();
    final result = await client.rpc('admin_get_game_data', params: {'p_game': gameId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> adminUpdateGame(String gameId, Map<String, dynamic> patch) async {
    _requireAuth();
    await client.rpc('admin_update_game', params: {'p_game': gameId, 'p_patch': patch});
  }

  Future<void> adminUpdateEntity({required String entity, required String id, required Map<String, dynamic> patch}) async {
    _requireAuth();
    await client.rpc('admin_update_entity', params: {'p_entity': entity, 'p_id': id, 'p_patch': patch});
  }

  Future<String> adminAdjustBalance({required String playerId, required int amount, String currency = 'USD', String reason = 'admin_adjustment'}) async {
    _requireAuth();
    final result = await client.rpc('admin_adjust_balance', params: {
      'p_player': playerId,
      'p_amount': amount,
      'p_currency': currency,
      'p_reason': reason,
    });
    return result.toString();
  }

  Future<void> _lifecycle(String function, String gameId) async {
    _requireAuth();
    await client.rpc(function, params: {'p_game': gameId});
  }

  void _requireAuth() {
    if (client.auth.currentUser == null) throw StateError('You must be signed in to perform this action.');
  }
}
