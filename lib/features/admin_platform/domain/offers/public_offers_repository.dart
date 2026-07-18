import '../common/cursor_page.dart';
import 'public_offer.dart';
import 'public_offer_input.dart';

abstract interface class PublicOffersRepository {
  Future<CursorPage<PublicOffer>> listOffers({String? cursor, int? limit});

  Future<PublicOffer> createOffer(PublicOfferInput input);

  Future<PublicOffer> updateOffer({
    required String offerId,
    required PublicOfferInput input,
  });

  Future<PublicOffer> setOfferPublished({
    required String offerId,
    required bool isPublished,
  });
}
