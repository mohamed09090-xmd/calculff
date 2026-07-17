import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/offers/public_offer_dto.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/offers/public_offer_input_mapper.dart';

void main() {
  group('PublicOfferDto', () {
    test('maps an offer with its nested game data', () {
      final offer = PublicOfferDto.fromMap(_offerPayload()).toDomain();

      expect(offer.id, '11111111-1111-1111-1111-111111111111');
      expect(offer.gameId, '22222222-2222-2222-2222-222222222222');
      expect(offer.gameNameAr, 'فري فاير');
      expect(offer.gameNameFr, 'Free Fire');
      expect(offer.rewardUnitNameAr, 'جوهرة');
      expect(offer.rewardUnitNameFr, 'Diamant');
      expect(offer.nameAr, 'عرض 100 جوهرة');
      expect(offer.nameFr, 'Offre 100 diamants');
      expect(offer.rewardQuantity, 100);
      expect(offer.salePriceDzd, 350);
      expect(offer.isPublished, isTrue);
      expect(offer.sortOrder, 2);
      expect(offer.createdAt.isUtc, isTrue);
      expect(offer.updatedAt.isUtc, isTrue);
    });

    test('rejects a missing nested game', () {
      final payload = _offerPayload()..remove('game');

      expect(
        () => PublicOfferDto.fromMap(payload),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'game',
          ),
        ),
      );
    });

    test('rejects mismatched nested game identifiers', () {
      final payload = _offerPayload();
      final game = Map<String, Object?>.from(
        payload['game']! as Map<String, Object?>,
      )..['id'] = '33333333-3333-3333-3333-333333333333';
      payload['game'] = game;

      expect(
        () => PublicOfferDto.fromMap(payload),
        throwsA(
          isA<PlatformPayloadException>()
              .having((error) => error.field, 'field', 'game.id')
              .having(
                (error) => error.reason,
                'reason',
                PlatformPayloadFailureReason.invalidValue,
              ),
        ),
      );
    });

    test('rejects wrong integer and boolean types', () {
      final wrongInteger = _offerPayload()..['reward_quantity'] = '100';
      final wrongBoolean = _offerPayload()..['is_published'] = 1;

      expect(
        () => PublicOfferDto.fromMap(wrongInteger),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'reward_quantity',
          ),
        ),
      );
      expect(
        () => PublicOfferDto.fromMap(wrongBoolean),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'is_published',
          ),
        ),
      );
    });
  });

  group('PublicOfferInputMapper', () {
    test('writes only the seven approved columns', () {
      final payload = PublicOfferInputMapper.toWritePayload(
        PublicOfferInput(
          gameId: ' 22222222-2222-2222-2222-222222222222 ',
          nameAr: ' عرض 100 جوهرة ',
          nameFr: ' Offre 100 diamants ',
          rewardQuantity: 100,
          salePriceDzd: 350,
          isPublished: true,
          sortOrder: 2,
        ),
      );

      expect(payload.keys.toSet(), <String>{
        'game_id',
        'name_ar',
        'name_fr',
        'reward_quantity',
        'sale_price_dzd',
        'is_published',
        'sort_order',
      });
      expect(payload['game_id'], '22222222-2222-2222-2222-222222222222');
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('created_at')));
      expect(payload, isNot(contains('updated_at')));
      expect(payload, isNot(contains('cost')));
      expect(payload, isNot(contains('profit')));
      expect(payload, isNot(contains('inventory')));
      expect(payload, isNot(contains('stock')));
    });
  });
}

Map<String, Object?> _offerPayload() {
  return <String, Object?>{
    'id': '11111111-1111-1111-1111-111111111111',
    'game_id': '22222222-2222-2222-2222-222222222222',
    'name_ar': 'عرض 100 جوهرة',
    'name_fr': 'Offre 100 diamants',
    'reward_quantity': 100,
    'sale_price_dzd': 350,
    'is_published': true,
    'sort_order': 2,
    'created_at': '2026-07-17T12:00:00+01:00',
    'updated_at': '2026-07-18T12:00:00+01:00',
    'game': <String, Object?>{
      'id': '22222222-2222-2222-2222-222222222222',
      'name_ar': 'فري فاير',
      'name_fr': 'Free Fire',
      'reward_unit_name_ar': 'جوهرة',
      'reward_unit_name_fr': 'Diamant',
    },
  };
}
