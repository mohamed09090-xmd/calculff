import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/offers/offers_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/offers/offers_screen.dart';

import 'offers_test_fakes.dart';

void main() {
  testWidgets('Arabic list is RTL and supports publishing controls', (
    tester,
  ) async {
    final offers = FakePublicOffersRepository(offers: [sampleOffer()]);
    await _pumpOffers(tester, offersRepository: offers);

    expect(find.text('إدارة العروض العامة'), findsOneWidget);
    expect(find.text('عرض 100 جوهرة'), findsOneWidget);
    expect(find.byKey(const Key('offers-list')), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(Key('offer-publish-$offerId')));
    await tester.pumpAndSettle();
    expect(offers.publishCalls, 1);
  });

  testWidgets('French list is LTR and localized', (tester) async {
    await _pumpOffers(
      tester,
      offersRepository: FakePublicOffersRepository(offers: [sampleOffer()]),
      locale: const Locale('fr', 'FR'),
    );

    expect(find.text('Gestion des offres publiques'), findsOneWidget);
    expect(find.text('Offre 100 diamants'), findsOneWidget);
    expect(find.text('Free Fire'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('offline state supports retry and pull to refresh', (
    tester,
  ) async {
    final offers = FakePublicOffersRepository(
      listFailure: const PlatformFailure(
        PlatformFailureCode.networkUnavailable,
      ),
    );
    await _pumpOffers(tester, offersRepository: offers);

    expect(find.byKey(const Key('offers-offline-state')), findsOneWidget);
    expect(find.byKey(const Key('offers-retry-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('offers-retry-button')));
    await tester.pumpAndSettle();
    expect(offers.listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('stale data remains visible after refresh failure', (
    tester,
  ) async {
    final offers = FakePublicOffersRepository(offers: [sampleOffer()]);
    await _pumpOffers(tester, offersRepository: offers);
    offers.listFailure = const PlatformFailure(
      PlatformFailureCode.networkUnavailable,
    );

    await tester.tap(find.byKey(const Key('offers-refresh-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('offers-stale-banner')), findsOneWidget);
    expect(find.text('عرض 100 جوهرة'), findsOneWidget);
  });

  testWidgets('320 by 640 with text scale 2 has no overflow', (tester) async {
    await _pumpOffers(
      tester,
      offersRepository: FakePublicOffersRepository(offers: [sampleOffer()]),
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const Key('offers-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer form is scrollable and blocks inactive publication', (
    tester,
  ) async {
    await _pumpOffers(
      tester,
      offersRepository: FakePublicOffersRepository(),
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    await tester.tap(find.byKey(const Key('offers-add-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('offer-form-scroll-view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('offer-game-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('لعبة متوقفة').last);
    await tester.pumpAndSettle();
    final formScrollable = find.descendant(
      of: find.byKey(const Key('offer-form-scroll-view')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('offer-published-field')),
      240,
      scrollable: formScrollable,
    );
    await tester.tap(find.byKey(const Key('offer-published-field')));
    await tester.pumpAndSettle();
    expect(find.text('لا يمكن نشر عرض تابع للعبة غير فعالة.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions and offer cards expose semantics', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpOffers(
        tester,
        offersRepository: FakePublicOffersRepository(offers: [sampleOffer()]),
      );

      expect(find.bySemanticsLabel('تحديث العروض'), findsWidgets);
      expect(find.bySemanticsLabel('إنشاء عرض'), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp('عرض عرض 100 جوهرة، مخفي')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('تعديل العرض عرض 100 جوهرة')),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });
}

Future<void> _pumpOffers(
  WidgetTester tester, {
  required FakePublicOffersRepository offersRepository,
  Locale locale = const Locale('ar', 'DZ'),
  Size size = const Size(390, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicOffersRepositoryProvider.overrideWithValue(offersRepository),
        offersGamesRepositoryProvider.overrideWithValue(FakeGamesRepository()),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ar', 'DZ'), Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const OffersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
