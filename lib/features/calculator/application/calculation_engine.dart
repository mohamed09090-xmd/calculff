import '../../../shared/models/calculation.dart';
import '../../../shared/models/credit_package.dart';
import '../../../shared/models/product.dart';
import 'credit_sale_pricing.dart';
import 'package_optimizer.dart';

class CalculationEngine {
  const CalculationEngine({this.optimizer = const PackageOptimizer()});
  final PackageOptimizer optimizer;

  CalculationResult calculate({
    required CalculationRequest request,
    required List<CreditPackage> packages,
    required int availableInventoryCredit,
    CreditSalePricing pricing = const CreditSalePricing(
      referenceCredit: 240,
      referencePriceDzd: 350,
    ),
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
        final product = _requireGemProduct(request.product);
        customerPaid = request.inputValue;
        units = customerPaid ~/ product.salePriceDzd;
        gems = units * product.gemsPerUnit;
        chargedAmount = units * product.salePriceDzd;
        customerChange = customerPaid - chargedAmount;
        requiredCredit = units * product.creditPerUnit;
        if (units == 0) warning = 'المبلغ أقل من سعر أصغر حزمة للمنتج';
        break;
      case CalculationMode.gems:
        final product = _requireGemProduct(request.product);
        final requestedGems = request.inputValue;
        units = requestedGems ~/ product.gemsPerUnit;
        final remainder = requestedGems % product.gemsPerUnit;
        if (remainder != 0) {
          final lower = units * product.gemsPerUnit;
          final upper = (units + 1) * product.gemsPerUnit;
          warning =
              'الكمية غير متوافقة مع الحزمة. الأقرب: $lower أو $upper جوهرة.';
        }
        gems = units * product.gemsPerUnit;
        chargedAmount = units * product.salePriceDzd;
        customerPaid = chargedAmount;
        requiredCredit = units * product.creditPerUnit;
        break;
      case CalculationMode.credit:
        requiredCredit = request.inputValue;
        chargedAmount = pricing.priceFor(requiredCredit);
        customerPaid = chargedAmount;
        units = 1;
        break;
      case CalculationMode.directProduct:
        final product = request.product;
        if (product == null || product.type != ProductType.direct) {
          throw ArgumentError('المنتج المباشر مطلوب');
        }
        requiredCredit = product.creditPerUnit;
        chargedAmount = pricing.priceFor(requiredCredit);
        customerPaid = chargedAmount;
        units = 1;
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
    final plannedPackageCost = optimization?.totalCost ?? 0;

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
      creditCostUsed: plannedPackageCost,
      cashProfit: chargedAmount - plannedPackageCost,
      warning: warning,
    );
  }

  Product _requireGemProduct(Product? product) {
    if (product == null || product.type != ProductType.gems) {
      throw ArgumentError('منتج الجواهر مطلوب');
    }
    return product;
  }
}
