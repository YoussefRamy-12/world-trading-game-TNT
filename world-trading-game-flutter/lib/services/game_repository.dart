import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/country.dart';

class GameRepository {
  final SupabaseClient client;

  GameRepository({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  Future<List<Country>> fetchCountries() async {
    final rows = await client
        .from('countries')
        .select('id, name, code, population, resources, owner_player_id')
        .order('name');

    return (rows as List)
        .map((row) => Country.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Country>> fetchPublicCountriesWithValues() async {
    final rows = await client
        .from('countries')
        .select('id, name, code, population, resources, owner_player_id, metadata')
        .eq('metadata->>public', 'true')
        .order('name');

    final result = <Country>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      try {
        final value = await client.rpc('country_value', params: {'p_country': map['id']});
        map['value'] = value is List && value.isNotEmpty ? value.first : value;
      } catch (_) {
        // Keep country data usable if the optional valuation RPC is unavailable to the anon role.
      }
      result.add(Country.fromMap(map));
    }
    return result;
  }
}
