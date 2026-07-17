import '../../domain/games/game.dart';
import '../common/platform_payload_reader.dart';

class GameDto {
  const GameDto({
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

  factory GameDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    return GameDto(
      id: reader.requiredUuid('id'),
      slug: reader.requiredString('slug'),
      nameAr: reader.requiredString('name_ar'),
      nameFr: reader.requiredString('name_fr'),
      rewardUnitCode: reader.requiredString('reward_unit_code'),
      rewardUnitNameAr: reader.requiredString('reward_unit_name_ar'),
      rewardUnitNameFr: reader.requiredString('reward_unit_name_fr'),
      isActive: reader.requiredBool('is_active'),
      sortOrder: reader.requiredInt('sort_order'),
      createdAt: reader.requiredDateTime('created_at'),
      updatedAt: reader.requiredDateTime('updated_at'),
    );
  }

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

  Game toDomain() {
    return Game(
      id: id,
      slug: slug,
      nameAr: nameAr,
      nameFr: nameFr,
      rewardUnitCode: rewardUnitCode,
      rewardUnitNameAr: rewardUnitNameAr,
      rewardUnitNameFr: rewardUnitNameFr,
      isActive: isActive,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
