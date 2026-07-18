import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/games/games_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/offers/offers_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/customer_platform_shell.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/games/games_screen.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/offers/offers_screen.dart';

import 'offers_test_fakes.dart';

void main() {
  test('offers reuse the repository exposed by gamesRepositoryProvider', () {
    final gamesRepository = FakeGamesRepository();
    final container = ProviderContainer(
      overrides: [
        gamesRepositoryProvider.overrideWithValue(gamesRepository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(offersGamesRepositoryProvider),
      same(gamesRepository),
    );
  });

  testWidgets('games and offers destinations preserve both real screens', (
    tester,
  ) async {
    await _pumpShell(tester, locale: const Locale('ar', 'DZ'));

    await tester.tap(find.text('الألعاب'));
    await tester.pumpAndSettle();
    expect(find.byType(GamesScreen), findsOneWidget);
    expect(find.byKey(const Key('games-list-view')), findsOneWidget);

    await tester.tap(find.text('العروض العامة'));
    await tester.pumpAndSettle();
    expect(find.byType(OffersScreen), findsOneWidget);
    expect(find.byKey(const Key('offers-list')), findsOneWidget);
    expect(
      find.byKey(const Key('platform-placeholder-scroll-view')),
      findsNothing,
    );
  });

  testWidgets('Arabic offers integration is RTL', (tester) async {
    await _pumpShell(tester, locale: const Locale('ar', 'DZ'));

    await tester.tap(find.text('العروض العامة'));
    await tester.pumpAndSettle();

    expect(find.text('إدارة العروض العامة'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('French offers integration is LTR and localized', (tester) async {
    await _pumpShell(tester, locale: const Locale('fr', 'FR'));

    await tester.tap(find.text('Offres publiques'));
    await tester.pumpAndSettle();

    expect(find.text('Gestion des offres publiques'), findsOneWidget);
    expect(find.text('Offre 100 diamants'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('offers integration fits 320 by 640 at 200 percent text', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      locale: const Locale('ar', 'DZ'),
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    await tester.tap(find.text('العروض العامة'));
    await tester.pumpAndSettle();

    expect(find.byType(OffersScreen), findsOneWidget);
    expect(find.byKey(const Key('offers-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('integrated destination semantics close cleanly', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpShell(tester, locale: const Locale('ar', 'DZ'));

      expect(find.bySemanticsLabel(RegExp('العروض العامة')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('الألعاب')), findsWidgets);

      await tester.tap(find.text('العروض العامة'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('تحديث العروض'), findsWidgets);
      expect(find.bySemanticsLabel('إنشاء عرض'), findsWidgets);
    } finally {
      semantics.dispose();
    }

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Locale locale,
  Size size = const Size(390, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final gamesRepository = FakeGamesRepository();
  final offersRepository = FakePublicOffersRepository(
    offers: [sampleOffer()],
    games: gamesRepository.games,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gamesRepositoryProvider.overrideWithValue(gamesRepository),
        publicOffersRepositoryProvider.overrideWithValue(offersRepository),
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
        home: CustomerPlatformShell(onSignOut: () async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
