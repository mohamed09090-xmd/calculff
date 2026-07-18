import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/dashboard/platform_dashboard_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/dashboard/platform_dashboard_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/dashboard/platform_dashboard_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/dashboard/platform_dashboard_summary.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/customer_platform_shell.dart';

void main() {
  testWidgets('contains the four platform destinations and dashboard', (
    tester,
  ) async {
    await _pumpShell(tester, size: const Size(390, 800));

    expect(find.text('لوحة المنصة'), findsWidgets);
    expect(find.text('الطلبات'), findsOneWidget);
    expect(find.text('العروض العامة'), findsOneWidget);
    expect(find.text('الألعاب'), findsOneWidget);
    expect(find.byKey(const Key('platform-dashboard-list-view')), findsOneWidget);
  });

  testWidgets('small layouts use NavigationBar', (tester) async {
    await _pumpShell(tester, size: const Size(360, 640));

    expect(find.byKey(const Key('platform-navigation-bar')), findsOneWidget);
    expect(find.byKey(const Key('platform-navigation-rail')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layouts use NavigationRail', (tester) async {
    await _pumpShell(tester, size: const Size(1000, 720));

    expect(find.byKey(const Key('platform-navigation-rail')), findsOneWidget);
    expect(find.byKey(const Key('platform-navigation-bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic is RTL', (tester) async {
    await _pumpShell(
      tester,
      size: const Size(390, 800),
      locale: const Locale('ar', 'DZ'),
    );

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('French is LTR and uses French destination labels', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: const Size(390, 800),
      locale: const Locale('fr', 'FR'),
    );

    expect(find.text('Plateforme clients'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Offres publiques'), findsOneWidget);
    expect(find.text('Jeux'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });

  testWidgets('small screen with 200 percent text has no overflow', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(ListView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator account hides identity and exposes logout', (
    tester,
  ) async {
    var signOutCalls = 0;
    await _pumpShell(
      tester,
      size: const Size(390, 800),
      onSignOut: () async => signOutCalls += 1,
    );

    await tester.tap(find.byKey(const Key('platform-admin-account-button')));
    await tester.pumpAndSettle();

    expect(find.text('حساب المدير'), findsWidgets);
    expect(find.text('الجلسة الحالية إدارية.'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('UUID'), findsNothing);
    expect(find.textContaining('token'), findsNothing);

    await tester.tap(find.byKey(const Key('platform-sign-out-button')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
  });

  testWidgets('navigation and account actions expose semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpShell(tester, size: const Size(390, 800));

      expect(find.bySemanticsLabel('حساب المدير'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('لوحة المنصة')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('الطلبات')), findsWidgets);
    } finally {
      handle.dispose();
    }
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  Locale locale = const Locale('ar', 'DZ'),
  TextScaler textScaler = TextScaler.noScaling,
  Future<void> Function()? onSignOut,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = PlatformDashboardController(
    repository: _DashboardRepository(),
  );
  await controller.load();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformDashboardControllerProvider.overrideWith((ref) => controller),
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
        home: CustomerPlatformShell(onSignOut: onSignOut ?? () async {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _DashboardRepository implements PlatformDashboardRepository {
  @override
  Future<PlatformDashboardSummary> loadDashboardSummary() async {
    return PlatformDashboardSummary(
      newOrdersCount: 0,
      processingOrdersCount: 0,
      paymentsUnderReviewCount: 0,
      completedOrdersCount: 0,
      publishedOffersCount: 0,
      activeGamesCount: 0,
      refreshedAt: DateTime.utc(2026, 7, 18, 12),
    );
  }
}
