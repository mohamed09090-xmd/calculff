class PublicOffer {
  const PublicOffer({
    required this.id,
    required this.gameId,
    required this.gameNameAr,
    required this.gameNameFr,
    required this.rewardUnitNameAr,
    required this.rewardUnitNameFr,
    required this.nameAr,
    required this.nameFr,
    required this.rewardQuantity,
    required this.salePriceDzd,
    required this.isPublished,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String gameId;
  final String gameNameAr;
  final String gameNameFr;
  final String rewardUnitNameAr;
  final String rewardUnitNameFr;
  final String nameAr;
  final String nameFr;
  final int rewardQuantity;
  final int salePriceDzd;
  final bool isPublished;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
