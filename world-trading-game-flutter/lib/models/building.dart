class BuildingType {
  final int id;
  final String slug;
  final String name;
  final int baseCost;
  final int baseIncome;
  final int maintenanceCost;
  final int maxLevel;

  const BuildingType({
    required this.id,
    required this.slug,
    required this.name,
    this.baseCost = 0,
    this.baseIncome = 0,
    this.maintenanceCost = 0,
    this.maxLevel = 1,
  });

  factory BuildingType.fromMap(Map<String, dynamic> map) => BuildingType(
        id: _int(map['id']),
        slug: (map['slug'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        baseCost: _int(map['base_cost']),
        baseIncome: _int(map['base_income']),
        maintenanceCost: _int(map['maintenance_cost']),
        maxLevel: _int(map['max_level'], 1),
      );

  static int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
}

class CountryBuilding {
  final String id;
  final String countryId;
  final int buildingTypeId;
  final int count;

  const CountryBuilding({
    required this.id,
    required this.countryId,
    required this.buildingTypeId,
    this.count = 1,
  });

  factory CountryBuilding.fromMap(Map<String, dynamic> map) => CountryBuilding(
        id: map['id'].toString(),
        countryId: map['country_id'].toString(),
        buildingTypeId: _int(map['building_type_id']),
        count: _int(map['count'], 1),
      );

  static int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
}
