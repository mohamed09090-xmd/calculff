import '../../domain/offers/public_offer_input.dart';

abstract final class PublicOfferInputMapper {
  static Map<String, Object> toWritePayload(PublicOfferInput input) {
    return Map<String, Object>.unmodifiable(<String, Object>{
      'game_id': input.gameId,
      'name_ar': input.nameAr,
      'name_fr': input.nameFr,
      'reward_quantity': input.rewardQuantity,
      'sale_price_dzd': input.salePriceDzd,
      'is_published': input.isPublished,
      'sort_order': input.sortOrder,
    });
  }
}
