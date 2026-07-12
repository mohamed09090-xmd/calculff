import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguagePreference { arabic, french }

extension AppLanguagePreferenceX on AppLanguagePreference {
  Locale get locale => switch (this) {
    AppLanguagePreference.arabic => const Locale('ar', 'DZ'),
    AppLanguagePreference.french => const Locale('fr', 'FR'),
  };

  TextDirection get textDirection => switch (this) {
    AppLanguagePreference.arabic => TextDirection.rtl,
    AppLanguagePreference.french => TextDirection.ltr,
  };

  String get languageCode => locale.languageCode;
}

class AppLanguageController extends AsyncNotifier<AppLanguagePreference> {
  static const _storageKey = 'appearance.language.v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  @override
  Future<AppLanguagePreference> build() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null) {
      return AppLanguagePreference.values.firstWhere(
        (language) => language.name == stored,
        orElse: () => AppLanguagePreference.arabic,
      );
    }

    return PlatformDispatcher.instance.locale.languageCode == 'fr'
        ? AppLanguagePreference.french
        : AppLanguagePreference.arabic;
  }

  Future<void> setLanguage(AppLanguagePreference language) async {
    state = AsyncData(language);
    await _storage.write(key: _storageKey, value: language.name);
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? AppLanguagePreference.arabic;
    await setLanguage(
      current == AppLanguagePreference.arabic
          ? AppLanguagePreference.french
          : AppLanguagePreference.arabic,
    );
  }
}

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguagePreference>(
      AppLanguageController.new,
    );
