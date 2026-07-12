import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../shared/providers/theme_mode_provider.dart';
import 'router.dart';
import 'theme.dart';

class GameCreditApp extends ConsumerWidget {
  const GameCreditApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themeModeProvider).valueOrNull ??
        AppThemeModePreference.system;
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preference.themeMode,
      locale: const Locale('ar', 'DZ'),
      supportedLocales: const [Locale('ar', 'DZ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: AppLockGate(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
