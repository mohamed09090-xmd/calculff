import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseOffersDataSource {
  Future<List<Map<String, Object?>>> listOffers({
    required int offset,
    required int limit,
  });

  Future<Map<String, Object?>> createOffer({
    required Map<String, Object> payload,
  });

  Future<Map<String, Object?>> updateOffer({
    required String offerId,
    required Map<String, Object> payload,
  });

  Future<Map<String, Object?>> setOfferPublished({
    required String offerId,
    required bool isPublished,
  });
}

class FlutterSupabaseOffersDataSource implements SupabaseOffersDataSource {
  const FlutterSupabaseOffersDataSource(this._client);

  static const offerSelection =
      'id,game_id,name_ar,name_fr,reward_quantity,sale_price_dzd,'
      'is_published,sort_order,created_at,updated_at,'
      'game:games!public_offers_game_id_fkey('
      'id,name_ar,name_fr,reward_unit_name_ar,reward_unit_name_fr,is_active)';

  final SupabaseClient _client;

  @override
  Future<List<Map<String, Object?>>> listOffers({
    required int offset,
    required int limit,
  }) async {
    final rows = await _client
        .from('public_offers')
        .select(offerSelection)
        .order('sort_order')
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows
        .map<Map<String, Object?>>(
          (row) => Map<String, Object?>.unmodifiable(row),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, Object?>> createOffer({
    required Map<String, Object> payload,
  }) async {
    final row = await _client
        .from('public_offers')
        .insert(payload)
        .select(offerSelection)
        .single();
    return Map<String, Object?>.unmodifiable(row);
  }

  @override
  Future<Map<String, Object?>> updateOffer({
    required String offerId,
    required Map<String, Object> payload,
  }) async {
    final row = await _client
        .from('public_offers')
        .update(payload)
        .eq('id', offerId)
        .select(offerSelection)
        .single();
    return Map<String, Object?>.unmodifiable(row);
  }

  @override
  Future<Map<String, Object?>> setOfferPublished({
    required String offerId,
    required bool isPublished,
  }) async {
    final row = await _client
        .from('public_offers')
        .update(<String, Object>{'is_published': isPublished})
        .eq('id', offerId)
        .select(offerSelection)
        .single();
    return Map<String, Object?>.unmodifiable(row);
  }
}
