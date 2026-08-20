import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Flutter client synchronized with changes made by other players.
///
/// This is intentionally client-only: it does not alter the existing Supabase
/// schema, RPCs, migrations, or database configuration.
class GameRealtimeService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  GameRealtimeService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  void subscribe({
    required String gameId,
    required FutureOr<void> Function() onChanged,
    void Function(Object error)? onError,
  }) {
    dispose();

    _channel = _client
        .channel('game-realtime-$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'countries',
          callback: (_) => _notify(onChanged, onError),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'country_buildings',
          callback: (_) => _notify(onChanged, onError),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'country_listings',
          callback: (_) => _notify(onChanged, onError),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bids',
          callback: (_) => _notify(onChanged, onError),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'games',
          callback: (_) => _notify(onChanged, onError),
        )
      ..subscribe((status, error) {
        if (error != null) onError?.call(error);
      });
  }

  Future<void> _notify(
    FutureOr<void> Function() callback,
    void Function(Object error)? onError,
  ) async {
    try {
      await callback();
    } catch (error) {
      onError?.call(error);
    }
  }

  void dispose() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_client.removeChannel(channel));
    }
  }
}
