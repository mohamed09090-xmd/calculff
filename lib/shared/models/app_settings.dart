class AppSettings {
  const AppSettings({
    required this.useThousands,
    required this.darkMode,
    required this.followSystemTheme,
    required this.expiryWarningHours,
  });

  final bool useThousands;
  final bool darkMode;
  final bool followSystemTheme;
  final int expiryWarningHours;

  AppSettings copyWith({
    bool? useThousands,
    bool? darkMode,
    bool? followSystemTheme,
    int? expiryWarningHours,
  }) =>
      AppSettings(
        useThousands: useThousands ?? this.useThousands,
        darkMode: darkMode ?? this.darkMode,
        followSystemTheme: followSystemTheme ?? this.followSystemTheme,
        expiryWarningHours: expiryWarningHours ?? this.expiryWarningHours,
      );

  static const defaults = AppSettings(
    useThousands: false,
    darkMode: false,
    followSystemTheme: true,
    expiryWarningHours: 24,
  );
}
