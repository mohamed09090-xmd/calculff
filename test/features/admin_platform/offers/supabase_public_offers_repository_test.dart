import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/offers/supabase_public_offers_repository.dart';

import 'offers_test_fakes.dart';

void main() {
  group('SupabasePublicOffersRepository', () {
    test('lists offers and retries one read after session expiry', () async {
      final dataSource = FakeSupabaseOffersDataSource(
        listOutcomes: <Object>[
          const PlatformFailure(PlatformFailureCode.sessionExpired),
          <Map<String, Object?>>[sampleOfferRow()],
        ],
      );
      final session = FakeSessionAccess();
      final scope = FakeDataScopeSink();
      final repository = SupabasePublicOffersRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: PlatformSessionCoordinator(
          sessionAccess: session,
          mapError: const SupabasePlatformErrorMapper().map,
          dataScope: scope,
        ),
      );

      final page = await repository.listOffers(limit: 20);

      expect(page.items, hasLength(1));
      expect(page.items.single.id, offerId);
      expect(dataSource.listCalls, 2);
      expect(session.refreshCalls, 1);
      expect(scope.invalidations, contains(PlatformFailureCode.sessionExpired));
    });

    test('maps offline reads without retrying', () async {
      final dataSource = FakeSupabaseOffersDataSource(
        listOutcomes: <Object>[
          const PlatformFailure(PlatformFailureCode.networkUnavailable),
        ],
      );
      final repository = SupabasePublicOffersRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: const ImmediateReadCoordinator(),
      );

      await expectLater(
        repository.listOffers(),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.networkUnavailable,
          ),
        ),
      );
      expect(dataSource.listCalls, 1);
    });

    test('maps malformed response safely', () async {
      final malformed = sampleOfferRow()..remove('sale_price_dzd');
      final dataSource = FakeSupabaseOffersDataSource(
        listOutcomes: <Object>[
          <Map<String, Object?>>[malformed],
        ],
      );
      final repository = SupabasePublicOffersRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: const ImmediateReadCoordinator(),
      );

      await expectLater(
        repository.listOffers(),
        throwsA(isA<PlatformPayloadException>()),
      );
    });

    test('create and update send only approved offer columns', () async {
      final dataSource = FakeSupabaseOffersDataSource();
      final repository = SupabasePublicOffersRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: const ImmediateReadCoordinator(),
      );
      final input = PublicOfferInput(
        gameId: activeGameId,
        nameAr: 'عرض',
        nameFr: 'Offre',
        rewardQuantity: 100,
        salePriceDzd: 350,
        isPublished: true,
        sortOrder: 2,
      );

      await repository.createOffer(input);
      await repository.updateOffer(offerId: offerId, input: input);

      const approved = <String>{
        'game_id',
        'name_ar',
        'name_fr',
        'reward_quantity',
        'sale_price_dzd',
        'is_published',
        'sort_order',
      };
      expect(dataSource.lastCreatePayload!.keys.toSet(), approved);
      expect(dataSource.lastUpdatePayload!.keys.toSet(), approved);
      final serialized = <Object?>[
        dataSource.lastCreatePayload,
        dataSource.lastUpdatePayload,
      ].join(' ').toLowerCase();
      expect(serialized, isNot(contains('cost')));
      expect(serialized, isNot(contains('profit')));
      expect(serialized, isNot(contains('inventory')));
      expect(serialized, isNot(contains('snapshot')));
    });

    test('writes are not retried after session expiry', () async {
      final dataSource = FakeSupabaseOffersDataSource(
        createOutcome: const PlatformFailure(
          PlatformFailureCode.sessionExpired,
        ),
      );
      final repository = SupabasePublicOffersRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: const ImmediateReadCoordinator(),
      );
      final input = PublicOfferInput(
        gameId: activeGameId,
        nameAr: 'عرض',
        nameFr: 'Offre',
        rewardQuantity: 100,
        salePriceDzd: 350,
      );

      await expectLater(
        repository.createOffer(input),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.sessionExpired,
          ),
        ),
      );
      expect(dataSource.createCalls, 1);
    });
  });
}
