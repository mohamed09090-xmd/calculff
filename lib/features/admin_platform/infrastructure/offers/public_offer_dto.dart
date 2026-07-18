import '../../domain/offers/public_offer.dart';
import '../common/platform_payload_reader.dart';

class PublicOfferDto {
  const PublicOfferDto({
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

  factory PublicOfferDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    final gameId = reader.requiredUuid('game_id');
    final gameReader = PlatformPayloadReader(reader.requiredMap('game'));
    final nestedGameId = gameReader.requiredUuid('id');
    if (nestedGameId != gameId) {
      throw const PlatformPayloadException(
        field: 'game.id',
        reason: PlatformPayloadFailureReason.invalidValue,
      );
    }

    return PublicOfferDto(
      id: reader.requiredUuid('id'),
      gameId: gameId,
      gameNameAr: gameReader.requiredString('name_ar'),
      gameNameFr: gameReader.requiredString('name_fr'),
      rewardUnitNameAr: gameReader.requiredString('reward_unit_name_ar'),
      rewardUnitNameFr: gameReader.requiredString('reward_unit_name_fr'),
      nameAr: reader.requiredString('name_ar'),
      nameFr: reader.requiredString('name_fr'),
      rewardQuantity: reader.requiredInt('reward_quantity'),
      salePriceDzd: reader.requiredInt('sale_price_dzd'),
      isPublished: reader.requiredBool('is_published'),
      sortOrder: reader.requiredInt('sort_order'),
      createdAt: reader.requiredDateTime('created_at'),
      updatedAt: reader.requiredDateTime('updated_at'),
    );
  }

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

  PublicOffer toDomain() {
    return PublicOffer(
      id: id,
      gameId: gameId,
      gameNameAr: gameNameAr,
      gameNameFr: gameNameFr,
      rewardUnitNameAr: rewardUnitNameAr,
      rewardUnitNameFr: rewardUnitNameFr,
      nameAr: nameAr,
      nameFr: nameFr,
      rewardQuantity: rewardQuantity,
      salePriceDzd: salePriceDzd,
      isPublished: isPublished,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
