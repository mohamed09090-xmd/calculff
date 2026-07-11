import 'credit_package.dart';

class PackageSelection {
  const PackageSelection({required this.package, required this.quantity});
  final CreditPackage package;
  final int quantity;

  int get totalCost => package.priceDzd * quantity;
  int get totalCredit => package.credit * quantity;
}

class OptimizationResult {
  const OptimizationResult({
    required this.requiredCredit,
    required this.selections,
    required this.totalCost,
    required this.totalCredit,
    required this.minimumValidityHours,
  });

  final int requiredCredit;
  final List<PackageSelection> selections;
  final int totalCost;
  final int totalCredit;
  final int minimumValidityHours;

  int get excessCredit => totalCredit - requiredCredit;
  int get packageCount =>
      selections.fold(0, (sum, item) => sum + item.quantity);
}
