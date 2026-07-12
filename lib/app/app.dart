import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../shared/providers/app_language_provider.dart';
import '../shared/providers/theme_mode_provider.dart';
import 'router.dart';
import 'theme.dart';

class GameCreditApp extends ConsumerWidget {
  const GameCreditApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeModeProvider).valueOrNull ??
        AppThemeModePreference.system;
    final languagePreference = ref.watch(appLanguageProvider).valueOrNull ??
        AppLanguagePreference.arabic;

    return MaterialApp.router(
      title: languagePreference == AppLanguagePreference.french
          ? 'Gestionnaire de crédit de jeux'
          : AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePreference.themeMode,
      locale: languagePreference.locale,
      supportedLocales: const [
        Locale('ar', 'DZ'),
        Locale('fr', 'FR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: languagePreference.textDirection,
        child: AppLockGate(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
