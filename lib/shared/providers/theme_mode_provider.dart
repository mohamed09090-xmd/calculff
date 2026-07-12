import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemeModePreference { system, light, dark }

extension AppThemeModePreferenceX on AppThemeModePreference {
  ThemeMode get themeMode => switch (this) {
    AppThemeModePreference.system => ThemeMode.system,
    AppThemeModePreference.light => ThemeMode.light,
    AppThemeModePreference.dark => ThemeMode.dark,
  };

  bool isDark(Brightness platformBrightness) => switch (this) {
    AppThemeModePreference.system => platformBrightness == Brightness.dark,
    AppThemeModePreference.light => false,
    AppThemeModePreference.dark => true,
  };
}

class ThemeModeController extends AsyncNotifier<AppThemeModePreference> {
  static const _storageKey = 'appearance.theme_mode.v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  @override
  Future<AppThemeModePreference> build() async {
    final stored = await _storage.read(key: _storageKey);
    return AppThemeModePreference.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => AppThemeModePreference.system,
    );
  }

  Future<void> setMode(AppThemeModePreference mode) async {
    state = AsyncData(mode);
    await _storage.write(key: _storageKey, value: mode.name);
  }

  Future<void> followSystem(bool enabled, Brightness currentBrightness) async {
    if (enabled) {
      await setMode(AppThemeModePreference.system);
      return;
    }
    await setMode(
      currentBrightness == Brightness.dark
          ? AppThemeModePreference.dark
          : AppThemeModePreference.light,
    );
  }

  Future<void> setDarkMode(bool enabled) => setMode(
    enabled ? AppThemeModePreference.dark : AppThemeModePreference.light,
  );
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, AppThemeModePreference>(
      ThemeModeController.new,
    );
