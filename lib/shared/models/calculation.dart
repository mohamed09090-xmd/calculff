import 'optimization_result.dart';
import 'product.dart';

enum CalculationMode { customerAmount, gems, credit, directProduct }

class CalculationRequest {
  const CalculationRequest({
    required this.mode,
    this.product,
    required this.inputValue,
    required this.useInventory,
  });

  final CalculationMode mode;
  final Product? product;
  final int inputValue;
  final bool useInventory;
}

class CalculationResult {
  const CalculationResult({
    required this.request,
    required this.units,
    required this.gems,
    required this.customerPaid,
    required this.chargedAmount,
    required this.customerChange,
    required this.requiredCredit,
    required this.inventoryCreditUsed,
    required this.additionalCreditRequired,
    required this.optimization,
    required this.creditCostUsed,
    required this.cashProfit,
    this.warning,
  });

  final CalculationRequest request;
  final int units;
  final int gems;
  final int customerPaid;
  final int chargedAmount;
  final int customerChange;
  final int requiredCredit;
  final int inventoryCreditUsed;
  final int additionalCreditRequired;
  final OptimizationResult? optimization;
  final int creditCostUsed;
  final int cashProfit;
  final String? warning;

  int get purchasedCredit => optimization?.totalCredit ?? 0;
  int get newPackagesCost => optimization?.totalCost ?? 0;
  int get remainingPurchasedCredit =>
      purchasedCredit - additionalCreditRequired;
  double get marginPercent =>
      chargedAmount == 0 ? 0 : (cashProfit / chargedAmount) * 100;

  CalculationResult copyWith({
    int? creditCostUsed,
    int? cashProfit,
  }) {
    return CalculationResult(
      request: request,
      units: units,
      gems: gems,
      customerPaid: customerPaid,
      chargedAmount: chargedAmount,
      customerChange: customerChange,
      requiredCredit: requiredCredit,
      inventoryCreditUsed: inventoryCreditUsed,
      additionalCreditRequired: additionalCreditRequired,
      optimization: optimization,
      creditCostUsed: creditCostUsed ?? this.creditCostUsed,
      cashProfit: cashProfit ?? this.cashProfit,
      warning: warning,
    );
  }
}
