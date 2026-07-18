import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/offers/offers_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_validation.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer_input.dart';

import 'offers_test_fakes.dart';

void main() {
  group('OffersController', () {
    test('loads data and exposes empty state', () async {
      final repository = FakePublicOffersRepository();
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, OffersViewStatus.empty);
      expect(controller.state.games, hasLength(2));
    });

    test('exposes offline and stale data states', () async {
      final repository = FakePublicOffersRepository(offers: [sampleOffer()]);
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      repository.listFailure = const PlatformFailure(
        PlatformFailureCode.networkUnavailable,
      );
      await controller.refresh();

      expect(controller.state.status, OffersViewStatus.data);
      expect(controller.state.isStale, isTrue);
      expect(
        controller.state.failureCode,
        PlatformFailureCode.networkUnavailable,
      );

      final offlineController = OffersController(
        offersRepository: FakePublicOffersRepository(
          listFailure: const PlatformFailure(
            PlatformFailureCode.networkUnavailable,
          ),
        ),
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(offlineController.dispose);
      await offlineController.load();
      expect(offlineController.state.status, OffersViewStatus.offline);
    });

    test('requires game and positive quantity and price', () async {
      final repository = FakePublicOffersRepository();
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final result = await controller.createOffer(
        PublicOfferInput(
          gameId: '',
          nameAr: 'عرض',
          nameFr: 'Offre',
          rewardQuantity: 0,
          salePriceDzd: -1,
        ),
      );

      expect(result.status, OffersMutationStatus.validationFailure);
      expect(
        result.validationIssues,
        contains(
          const PlatformValidationIssue(
            field: PlatformValidationField.gameId,
            code: PlatformValidationCode.required,
          ),
        ),
      );
      expect(
        result.validationIssues,
        contains(
          const PlatformValidationIssue(
            field: PlatformValidationField.rewardQuantity,
            code: PlatformValidationCode.mustBePositive,
          ),
        ),
      );
      expect(
        result.validationIssues,
        contains(
          const PlatformValidationIssue(
            field: PlatformValidationField.salePriceDzd,
            code: PlatformValidationCode.mustBePositive,
          ),
        ),
      );
      expect(repository.createCalls, 0);
    });

    test('prevents publishing an offer for an inactive game', () async {
      final repository = FakePublicOffersRepository(
        offers: [sampleOffer(gameId: inactiveGameId)],
      );
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final createResult = await controller.createOffer(
        PublicOfferInput(
          gameId: inactiveGameId,
          nameAr: 'عرض',
          nameFr: 'Offre',
          rewardQuantity: 100,
          salePriceDzd: 350,
          isPublished: true,
        ),
      );
      final publishResult = await controller.setOfferPublished(
        offerId: offerId,
        isPublished: true,
      );

      expect(createResult.status, OffersMutationStatus.validationFailure);
      expect(publishResult.status, OffersMutationStatus.validationFailure);
      expect(repository.createCalls, 0);
      expect(repository.publishCalls, 0);
    });

    test('publishes and hides then refetches the list', () async {
      final repository = FakePublicOffersRepository(offers: [sampleOffer()]);
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final initialListCalls = repository.listCalls;

      final published = await controller.setOfferPublished(
        offerId: offerId,
        isPublished: true,
      );
      final hidden = await controller.setOfferPublished(
        offerId: offerId,
        isPublished: false,
      );

      expect(published.isSuccess, isTrue);
      expect(hidden.isSuccess, isTrue);
      expect(repository.publishCalls, 2);
      expect(repository.listCalls, initialListCalls + 2);
      expect(controller.state.offers.single.isPublished, isFalse);
    });

    test('prevents duplicate submit while a write is pending', () async {
      final gate = Completer<void>();
      final repository = FakePublicOffersRepository(createGate: gate);
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final input = PublicOfferInput(
        gameId: activeGameId,
        nameAr: 'عرض',
        nameFr: 'Offre',
        rewardQuantity: 100,
        salePriceDzd: 350,
      );

      final first = controller.createOffer(input);
      await Future<void>.delayed(Duration.zero);
      final second = await controller.createOffer(input);
      gate.complete();
      final firstResult = await first;

      expect(second.status, OffersMutationStatus.busy);
      expect(firstResult.isSuccess, isTrue);
      expect(repository.createCalls, 1);
    });

    test('surfaces session expiry from writes without retry', () async {
      final repository = FakePublicOffersRepository(
        createFailure: const PlatformFailure(
          PlatformFailureCode.sessionExpired,
        ),
      );
      final controller = OffersController(
        offersRepository: repository,
        gamesRepository: FakeGamesRepository(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final result = await controller.createOffer(
        PublicOfferInput(
          gameId: activeGameId,
          nameAr: 'عرض',
          nameFr: 'Offre',
          rewardQuantity: 100,
          salePriceDzd: 350,
        ),
      );

      expect(result.failureCode, PlatformFailureCode.sessionExpired);
      expect(repository.createCalls, 1);
    });
  });
}
