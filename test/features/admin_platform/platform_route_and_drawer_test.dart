import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/widgets/app_shell.dart';
import 'package:game_credit_profit_manager/shared/providers/app_language_provider.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('the local app remains the initial route without a global redirect', () {
    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final appSource = File('lib/app/app.dart').readAsStringSync();

    expect(routerSource, contains("initialLocation: '/'"));
    expect(routerSource, contains("path: '/platform'"));
    expect(routerSource, isNot(contains('redirect:')));
    expect(appSource, isNot(contains('AdminLoginScreen')));
    expect(appSource, isNot(contains('PlatformGate')));
  });

  testWidgets('drawer shows the Arabic platform entry and opens its route', (
    tester,
  ) async {
    await _pumpDrawer(tester, language: AppLanguagePreference.arabic);

    await _openDrawerAndRevealPlatformEntry(tester, 'منصة الزبائن');
    expect(find.text('منصة الزبائن'), findsOneWidget);
    expect(find.text('تسجيل دخول المدير'), findsNothing);

    await tester.tap(find.text('منصة الزبائن'));
    await tester.pumpAndSettle();
    expect(find.text('platform-open'), findsOneWidget);
  });

  testWidgets('drawer shows Plateforme clients in French', (tester) async {
    await _pumpDrawer(tester, language: AppLanguagePreference.french);

    await _openDrawerAndRevealPlatformEntry(tester, 'Plateforme clients');
    expect(find.text('Plateforme clients'), findsOneWidget);
  });

  testWidgets('drawer supports small screens with 200 percent text', (
    tester,
  ) async {
    await _pumpDrawer(
      tester,
      language: AppLanguagePreference.arabic,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    await _openDrawerAndRevealPlatformEntry(tester, 'منصة الزبائن');
    expect(find.text('منصة الزبائن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openDrawerAndRevealPlatformEntry(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();

  final drawerScrollable = find.descendant(
    of: find.byType(NavigationDrawer),
    matching: find.byType(Scrollable),
  );
  expect(drawerScrollable, findsOneWidget);

  await tester.scrollUntilVisible(
    find.text(label),
    240,
    scrollable: drawerScrollable,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDrawer(
  WidgetTester tester, {
  required AppLanguagePreference language,
  Size size = const Size(800, 600),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final locale = language.locale;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const AppShell(title: 'local-app', body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/platform',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('platform-open'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _TestLanguageController(language),
        ),
      ],
      child: MaterialApp.router(
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
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestLanguageController extends AppLanguageController {
  _TestLanguageController(this.language);

  final AppLanguagePreference language;

  @override
  Future<AppLanguagePreference> build() async => language;

  @override
  Future<void> toggle() async {}
}
