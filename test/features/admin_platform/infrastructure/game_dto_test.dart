import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/game_dto.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/game_input_mapper.dart';

void main() {
  group('GameDto', () {
    test('maps a complete payload to Game', () {
      final game = GameDto.fromMap(_gamePayload()).toDomain();

      expect(game.id, 'abcdef12-3456-7890-abcd-ef1234567890');
      expect(game.slug, 'free-fire');
      expect(game.nameAr, 'فري فاير');
      expect(game.nameFr, 'Free Fire');
      expect(game.rewardUnitCode, 'diamonds');
      expect(game.rewardUnitNameAr, 'جوهرة');
      expect(game.rewardUnitNameFr, 'Diamant');
      expect(game.isActive, isTrue);
      expect(game.sortOrder, 3);
      expect(game.createdAt, DateTime.utc(2026, 7, 17, 11));
      expect(game.updatedAt, DateTime.utc(2026, 7, 18, 11));
    });

    test('rejects a missing field', () {
      final payload = _gamePayload()..remove('name_ar');

      expect(
        () => GameDto.fromMap(payload),
        throwsA(
          isA<PlatformPayloadException>()
              .having((error) => error.field, 'field', 'name_ar')
              .having(
                (error) => error.reason,
                'reason',
                PlatformPayloadFailureReason.missingField,
              ),
        ),
      );
    });

    test('rejects a wrong field type', () {
      final payload = _gamePayload()..['is_active'] = 'true';

      expect(
        () => GameDto.fromMap(payload),
        throwsA(
          isA<PlatformPayloadException>()
              .having((error) => error.field, 'field', 'is_active')
              .having(
                (error) => error.reason,
                'reason',
                PlatformPayloadFailureReason.wrongType,
              ),
        ),
      );
    });

    test('rejects an invalid UUID and timestamp', () {
      final invalidUuid = _gamePayload()..['id'] = 'not-a-uuid';
      final invalidTimestamp = _gamePayload()
        ..['created_at'] = 'not-a-timestamp';

      expect(
        () => GameDto.fromMap(invalidUuid),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'id',
          ),
        ),
      );
      expect(
        () => GameDto.fromMap(invalidTimestamp),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'created_at',
          ),
        ),
      );
    });
  });

  group('GameInputMapper', () {
    test('writes only the eight approved columns', () {
      final payload = GameInputMapper.toWritePayload(
        GameInput(
          slug: ' free-fire ',
          nameAr: ' فري فاير ',
          nameFr: ' Free Fire ',
          rewardUnitCode: ' diamonds ',
          rewardUnitNameAr: ' جوهرة ',
          rewardUnitNameFr: ' Diamant ',
          isActive: true,
          sortOrder: 3,
        ),
      );

      expect(payload.keys.toSet(), <String>{
        'slug',
        'name_ar',
        'name_fr',
        'reward_unit_code',
        'reward_unit_name_ar',
        'reward_unit_name_fr',
        'is_active',
        'sort_order',
      });
      expect(payload['slug'], 'free-fire');
      expect(payload, isNot(contains('id')));
      expect(payload, isNot(contains('created_at')));
      expect(payload, isNot(contains('updated_at')));
    });
  });
}

Map<String, Object?> _gamePayload() {
  return <String, Object?>{
    'id': 'ABCDEF12-3456-7890-ABCD-EF1234567890',
    'slug': 'free-fire',
    'name_ar': 'فري فاير',
    'name_fr': 'Free Fire',
    'reward_unit_code': 'diamonds',
    'reward_unit_name_ar': 'جوهرة',
    'reward_unit_name_fr': 'Diamant',
    'is_active': true,
    'sort_order': 3,
    'created_at': '2026-07-17T12:00:00+01:00',
    'updated_at': '2026-07-18T12:00:00+01:00',
  };
}
