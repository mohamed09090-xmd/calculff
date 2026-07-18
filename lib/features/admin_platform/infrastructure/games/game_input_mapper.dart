import '../../domain/games/game_input.dart';

abstract final class GameInputMapper {
  static Map<String, Object> toWritePayload(GameInput input) {
    return Map<String, Object>.unmodifiable(<String, Object>{
      'slug': input.slug,
      'name_ar': input.nameAr,
      'name_fr': input.nameFr,
      'reward_unit_code': input.rewardUnitCode,
      'reward_unit_name_ar': input.rewardUnitNameAr,
      'reward_unit_name_fr': input.rewardUnitNameFr,
      'is_active': input.isActive,
      'sort_order': input.sortOrder,
    });
  }
}
