class AppSettings {
  const AppSettings({
    required this.useThousands,
    required this.darkMode,
    required this.expiryWarningHours,
  });

  final bool useThousands;
  final bool darkMode;
  final int expiryWarningHours;

  AppSettings copyWith({
    bool? useThousands,
    bool? darkMode,
    int? expiryWarningHours,
  }) =>
      AppSettings(
        useThousands: useThousands ?? this.useThousands,
        darkMode: darkMode ?? this.darkMode,
        expiryWarningHours: expiryWarningHours ?? this.expiryWarningHours,
      );

  static const defaults = AppSettings(
    useThousands: false,
    darkMode: false,
    expiryWarningHours: 24,
  );
}
