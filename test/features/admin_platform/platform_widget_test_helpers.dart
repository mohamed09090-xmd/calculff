import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/admin_auth_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/platform_gate.dart';

Future<void> pumpPlatformGate(
  WidgetTester tester, {
  required AdminAuthRepository? repository,
  Locale locale = const Locale('ar', 'DZ'),
  bool settle = true,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminAuthRepositoryProvider.overrideWithValue(repository)],
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
        home: const PlatformGate(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
