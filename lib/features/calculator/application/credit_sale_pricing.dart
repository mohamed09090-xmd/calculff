class CreditSalePricing {
  const CreditSalePricing({
    required this.referenceCredit,
    required this.referencePriceDzd,
  }) : assert(referenceCredit > 0),
       assert(referencePriceDzd > 0);

  final int referenceCredit;
  final int referencePriceDzd;

  int priceFor(int credit) {
    if (credit <= 0) return 0;
    final numerator = credit * referencePriceDzd;
    final denominatorForTens = referenceCredit * 10;
    return ((numerator + (referenceCredit * 5)) ~/ denominatorForTens) * 10;
  }
}
