class AppSettings {
  const AppSettings({
    required this.useThousands,
    required this.darkMode,
    required this.expiryWarningHours,
    required this.creditSaleReferenceCredit,
    required this.creditSaleReferencePriceDzd,
  });

  final bool useThousands;
  final bool darkMode;
  final int expiryWarningHours;
  final int creditSaleReferenceCredit;
  final int creditSaleReferencePriceDzd;

  AppSettings copyWith({
    bool? useThousands,
    bool? darkMode,
    int? expiryWarningHours,
    int? creditSaleReferenceCredit,
    int? creditSaleReferencePriceDzd,
  }) =>
      AppSettings(
        useThousands: useThousands ?? this.useThousands,
        darkMode: darkMode ?? this.darkMode,
        expiryWarningHours: expiryWarningHours ?? this.expiryWarningHours,
        creditSaleReferenceCredit:
            creditSaleReferenceCredit ?? this.creditSaleReferenceCredit,
        creditSaleReferencePriceDzd:
            creditSaleReferencePriceDzd ?? this.creditSaleReferencePriceDzd,
      );

  static const defaults = AppSettings(
    useThousands: false,
    darkMode: false,
    expiryWarningHours: 24,
    creditSaleReferenceCredit: 240,
    creditSaleReferencePriceDzd: 350,
  );
}
