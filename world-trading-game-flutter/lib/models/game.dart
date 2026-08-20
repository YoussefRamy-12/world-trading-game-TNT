class Game {
  final String id;
  final String slug;
  final String name;
  final String status;
  final String state;
  final Map<String, dynamic> config;
  final int currentTick;
  final int tickIntervalSeconds;

  const Game({
    required this.id,
    required this.slug,
    required this.name,
    this.status = 'pending',
    this.state = 'draft',
    this.config = const {},
    this.currentTick = 0,
    this.tickIntervalSeconds = 3600,
  });

  factory Game.fromMap(Map<String, dynamic> map) => Game(
        id: map['id'].toString(),
        slug: (map['slug'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        status: (map['status'] ?? 'pending').toString(),
        state: (map['state'] ?? 'draft').toString(),
        config: Map<String, dynamic>.from(map['config'] is Map ? map['config'] as Map : {}),
        currentTick: _int(map['current_tick']),
        tickIntervalSeconds: _int(map['tick_interval_seconds'], 3600),
      );

  static int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
}
