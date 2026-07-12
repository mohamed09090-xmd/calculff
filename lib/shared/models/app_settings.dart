enum AppThemePreference { system, light, dark }

extension AppThemePreferenceX on AppThemePreference {
  String get storageValue => name;

  String get label => switch (this) {
        AppThemePreference.system => 'حسب سمة الهاتف',
        AppThemePreference.light => 'فاتح دائمًا',
        AppThemePreference.dark => 'داكن دائمًا',
      };

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.useThousands,
    required this.themePreference,
    required this.expiryWarningHours,
  });

  final bool useThousands;
  final AppThemePreference themePreference;
  final int expiryWarningHours;

  AppSettings copyWith({
    bool? useThousands,
    AppThemePreference? themePreference,
    int? expiryWarningHours,
  }) =>
      AppSettings(
        useThousands: useThousands ?? this.useThousands,
        themePreference: themePreference ?? this.themePreference,
        expiryWarningHours: expiryWarningHours ?? this.expiryWarningHours,
      );

  static const defaults = AppSettings(
    useThousands: false,
    themePreference: AppThemePreference.system,
    expiryWarningHours: 24,
  );
}
