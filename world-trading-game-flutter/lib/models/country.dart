class Country {
  final String id;
  final String name;
  final String? code;
  final int population;
  final dynamic resources;
  final String? ownerPlayerId;
  final int? value;

  const Country({
    required this.id,
    required this.name,
    this.code,
    this.population = 0,
    this.resources,
    this.ownerPlayerId,
    this.value,
  });

  factory Country.fromMap(Map<String, dynamic> map) {
    return Country(
      id: map['id'].toString(),
      name: (map['name'] ?? 'Unknown').toString(),
      code: map['code']?.toString(),
      population: _toInt(map['population']),
      resources: map['resources'],
      ownerPlayerId: map['owner_player_id']?.toString(),
      value: map['value'] == null ? null : _toInt(map['value']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
