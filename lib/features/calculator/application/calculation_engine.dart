import '../../../shared/models/calculation.dart';
import '../../../shared/models/credit_package.dart';
import 'package_optimizer.dart';

class CalculationEngine {
  const CalculationEngine({this.optimizer = const PackageOptimizer()});
  final PackageOptimizer optimizer;

  CalculationResult calculate({
    required CalculationRequest request,
    required List<CreditPackage> packages,
    required int availableInventoryCredit,
  }) {
    if (request.inputValue < 0) {
      throw ArgumentError.value(request.inputValue, 'inputValue');
    }

    var units = 0;
    var gems = 0;
    var customerPaid = 0;
    var chargedAmount = 0;
    var customerChange = 0;
    var requiredCredit = 0;
    String? warning;

    switch (request.mode) {
      case CalculationMode.customerAmount:
        final product = request.product ??
            (throw ArgumentError('المنتج مطلوب للحساب حسب المبلغ'));
        customerPaid = request.inputValue;
        units = customerPaid ~/ product.salePriceDzd;
        gems = units * product.gemsPerUnit;
        chargedAmount = units * product.salePriceDzd;
        customerChange = customerPaid - chargedAmount;
        requiredCredit = units * product.creditPerUnit;
        if (units == 0) warning = 'المبلغ أقل من سعر أصغر حزمة للمنتج';
        break;
      case CalculationMode.gems:
        final product = request.product ??
            (throw ArgumentError('المنتج مطلوب للحساب حسب الجواهر'));
        final requestedGems = request.inputValue;
        units = requestedGems ~/ product.gemsPerUnit;
        final remainder = requestedGems % product.gemsPerUnit;
        if (remainder != 0) {
          final lower = units * product.gemsPerUnit;
          final upper = (units + 1) * product.gemsPerUnit;
          warning = 'الكمية غير متوافقة مع الحزمة. الأقرب: $lower أو $upper جوهرة.';
        }
        gems = units * product.gemsPerUnit;
        chargedAmount = units * product.salePriceDzd;
        customerPaid = chargedAmount;
        requiredCredit = units * product.creditPerUnit;
        break;
      case CalculationMode.credit:
        requiredCredit = request.inputValue;
        break;
    }

    final inventoryUsed = request.useInventory
        ? (availableInventoryCredit < requiredCredit
            ? availableInventoryCredit
            : requiredCredit)
        : 0;
    final additional = requiredCredit - inventoryUsed;
    final optimization = additional == 0
        ? null
        : optimizer.optimize(requiredCredit: additional, packages: packages);
    final cost = optimization?.totalCost ?? 0;
    final profit = chargedAmount - cost;

    return CalculationResult(
      request: request,
      units: units,
      gems: gems,
      customerPaid: customerPaid,
      chargedAmount: chargedAmount,
      customerChange: customerChange,
      requiredCredit: requiredCredit,
      inventoryCreditUsed: inventoryUsed,
      additionalCreditRequired: additional,
      optimization: optimization,
      cashProfit: profit,
      warning: warning,
    );
  }
}
