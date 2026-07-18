import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/supabase_games_data_source.dart';

void main() {
  group('SupabaseGamesDataSource decoding', () {
    test('decodes the explicitly selected game fields', () {
      final games = SupabaseGamesDataSource.decodeListResponse(<Object?>[
        _gamePayload(),
      ]);

      expect(games, hasLength(1));
      expect(games.single.id, '11111111-1111-1111-1111-111111111111');
      expect(games.single.slug, 'free-fire');
      expect(games.single.sortOrder, 2);
      expect(games.single.isActive, isTrue);
    });

    test('rejects malformed list and row responses', () {
      expect(
        () => SupabaseGamesDataSource.decodeListResponse(<String, Object?>{}),
        throwsA(isA<PlatformPayloadException>()),
      );
      expect(
        () => SupabaseGamesDataSource.decodeListResponse(<Object?>['bad-row']),
        throwsA(isA<PlatformPayloadException>()),
      );
      expect(
        () => SupabaseGamesDataSource.decodeSingleResponse(<String, Object?>{
          ..._gamePayload(),
          'is_active': 'yes',
        }),
        throwsA(isA<PlatformPayloadException>()),
      );
    });
  });

  test('selectedColumns contains only the approved explicit columns', () {
    expect(
      SupabaseGamesDataSource.selectedColumns,
      'id,slug,name_ar,name_fr,reward_unit_code,reward_unit_name_ar,'
      'reward_unit_name_fr,is_active,sort_order,created_at,updated_at',
    );
    expect(SupabaseGamesDataSource.selectedColumns, isNot(contains('*')));
  });
}

Map<String, Object?> _gamePayload() => <String, Object?>{
  'id': '11111111-1111-1111-1111-111111111111',
  'slug': 'free-fire',
  'name_ar': 'فري فاير',
  'name_fr': 'Free Fire',
  'reward_unit_code': 'diamonds',
  'reward_unit_name_ar': 'جوهرة',
  'reward_unit_name_fr': 'Diamant',
  'is_active': true,
  'sort_order': 2,
  'created_at': '2026-07-18T10:00:00Z',
  'updated_at': '2026-07-18T11:00:00Z',
};
