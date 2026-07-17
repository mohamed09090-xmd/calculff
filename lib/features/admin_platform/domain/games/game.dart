class Game {
  const Game({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameFr,
    required this.rewardUnitCode,
    required this.rewardUnitNameAr,
    required this.rewardUnitNameFr,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameFr;
  final String rewardUnitCode;
  final String rewardUnitNameAr;
  final String rewardUnitNameFr;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
