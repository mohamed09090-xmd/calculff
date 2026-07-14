import '../../../shared/models/calculation.dart';
import '../../../shared/models/credit_package.dart';
import '../../../shared/models/optimization_result.dart';
import '../../../shared/models/product.dart';
import 'calculation_engine.dart';
import 'credit_sale_pricing.dart';
import 'package_optimizer.dart';

enum CalculationPrimaryInput { customerAmount, gems, credit, directProduct }

class CalculationValidationIssue {
  const CalculationValidationIssue({
    required this.code,
    required this.messageAr,
    required this.messageFr,
  });

  final String code;
  final String messageAr;
  final String messageFr;
}

class CalculationDraftValidationException implements Exception {
  const CalculationDraftValidationException(this.issues);

  final List<CalculationValidationIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.messageAr).join('\n');
}

class CalculationDraft {
  const CalculationDraft({
    required this.request,
    required this.availableInventoryCredit,
    required this.packages,
    required this.units,
    required this.gems,
    required this.salePrice,
    required this.customerPaid,
    required this.chargedAmount,
    required this.customerChange,
    required this.requiredCredit,
    required this.inventoryCreditUsed,
    required this.inventoryCostUsed,
    required this.optimization,
    this.warning,
  });

  final CalculationRequest request;
  final int availableInventoryCredit;
  final List<CreditPackage> packages;
  final int units;
  final int gems;
  final int salePrice;
  final int customerPaid;
  final int chargedAmount;
  final int customerChange;
  final int requiredCredit;
  final int inventoryCreditUsed;
  final int inventoryCostUsed;
  final OptimizationResult? optimization;
  final String? warning;

  CalculationPrimaryInput get primaryInput => switch (request.mode) {
    CalculationMode.customerAmount => CalculationPrimaryInput.customerAmount,
    CalculationMode.gems => CalculationPrimaryInput.gems,
    CalculationMode.credit => CalculationPrimaryInput.credit,
    CalculationMode.directProduct => CalculationPrimaryInput.directProduct,
  };

  int get primaryInputValue => request.inputValue;
  int get additionalCreditRequired => requiredCredit - inventoryCreditUsed;
  int get purchasedCredit => optimization?.totalCredit ?? 0;
  int get newPackagesCost => optimization?.totalCost ?? 0;
  int get remainingPurchasedCredit =>
      purchasedCredit - additionalCreditRequired;
  int get packageCreditCostUsed {
    var remaining = additionalCreditRequired;
    if (remaining <= 0 || optimization == null) return 0;
    final selections = [...optimization!.selections]
      ..sort((a, b) {
        final validity = a.package.validityHours.compareTo(
          b.package.validityHours,
        );
        if (validity != 0) return validity;
        return a.package.credit.compareTo(b.package.credit);
      });
    var cost = 0;
    for (final selection in selections) {
      for (
        var index = 0;
        index < selection.quantity && remaining > 0;
        index++
      ) {
        final used = remaining < selection.package.credit
            ? remaining
            : selection.package.credit;
        cost += ((selection.package.priceDzd * used) / selection.package.credit)
            .round();
        remaining -= used;
      }
    }
    return cost;
  }

  int get creditCostUsed => inventoryCostUsed + packageCreditCostUsed;
  int get cashProfit => chargedAmount - creditCostUsed;
  double get marginPercent =>
      chargedAmount == 0 ? 0 : (cashProfit / chargedAmount) * 100;

  CalculationDraft copyWith({
    CalculationRequest? request,
    int? availableInventoryCredit,
    List<CreditPackage>? packages,
    int? units,
    int? gems,
    int? salePrice,
    int? customerPaid,
    int? chargedAmount,
    int? customerChange,
    int? requiredCredit,
    int? inventoryCreditUsed,
    int? inventoryCostUsed,
    OptimizationResult? optimization,
    bool clearOptimization = false,
    String? warning,
    bool clearWarning = false,
  }) => CalculationDraft(
    request: request ?? this.request,
    availableInventoryCredit:
        availableInventoryCredit ?? this.availableInventoryCredit,
    packages: packages ?? this.packages,
    units: units ?? this.units,
    gems: gems ?? this.gems,
    salePrice: salePrice ?? this.salePrice,
    customerPaid: customerPaid ?? this.customerPaid,
    chargedAmount: chargedAmount ?? this.chargedAmount,
    customerChange: customerChange ?? this.customerChange,
    requiredCredit: requiredCredit ?? this.requiredCredit,
    inventoryCreditUsed: inventoryCreditUsed ?? this.inventoryCreditUsed,
    inventoryCostUsed: inventoryCostUsed ?? this.inventoryCostUsed,
    optimization: clearOptimization ? null : optimization ?? this.optimization,
    warning: clearWarning ? null : warning ?? this.warning,
  );
}

class CalculationDraftEngine {
  const CalculationDraftEngine({
    this.calculationEngine = const CalculationEngine(),
    this.optimizer = const PackageOptimizer(),
  });

  final CalculationEngine calculationEngine;
  final PackageOptimizer optimizer;

  CalculationDraft create({
    required CalculationRequest request,
    required List<CreditPackage> packages,
    required int availableInventoryCredit,
    CreditSalePricing pricing = const CreditSalePricing(
      referenceCredit: 240,
      referencePriceDzd: 350,
    ),
  }) {
    final result = calculationEngine.calculate(
      request: request,
      packages: packages,
      availableInventoryCredit: availableInventoryCredit,
      pricing: pricing,
    );
    return fromResult(
      result,
      packages: packages,
      availableInventoryCredit: availableInventoryCredit,
    );
  }

  CalculationDraft fromResult(
    CalculationResult result, {
    required List<CreditPackage> packages,
    required int availableInventoryCredit,
  }) {
    final salePrice = switch (result.request.mode) {
      CalculationMode.customerAmount || CalculationMode.gems =>
        result.units == 0
            ? result.request.product?.salePriceDzd ?? 0
            : result.chargedAmount ~/ result.units,
      CalculationMode.credit ||
      CalculationMode.directProduct => result.chargedAmount,
    };
    return CalculationDraft(
      request: result.request,
      availableInventoryCredit: availableInventoryCredit,
      packages: List<CreditPackage>.unmodifiable(packages),
      units: result.units,
      gems: result.gems,
      salePrice: salePrice,
      customerPaid: result.customerPaid,
      chargedAmount: result.chargedAmount,
      customerChange: result.customerChange,
      requiredCredit: result.requiredCredit,
      inventoryCreditUsed: result.inventoryCreditUsed,
      inventoryCostUsed: _initialInventoryCost(result, packages: packages),
      optimization: result.optimization,
      warning: result.warning,
    );
  }

  CalculationDraft updatePrimaryInput(
    CalculationDraft draft,
    int value, {
    CreditSalePricing pricing = const CreditSalePricing(
      referenceCredit: 240,
      referencePriceDzd: 350,
    ),
  }) {
    final request = CalculationRequest(
      mode: draft.request.mode,
      product: draft.request.product,
      inputValue: value,
      useInventory: draft.request.useInventory,
    );
    return create(
      request: request,
      packages: draft.packages,
      availableInventoryCredit: draft.availableInventoryCredit,
      pricing: pricing,
    );
  }

  CalculationDraft updateGems(CalculationDraft draft, int value) {
    final product = _requireGemProduct(draft.request.product);
    if (draft.request.mode == CalculationMode.gems) {
      return updatePrimaryInput(draft, value);
    }
    final units = value < 0 ? 0 : value ~/ product.gemsPerUnit;
    return _recalculateGemSale(
      draft,
      units: units,
      gems: value,
      warning: value >= 0 && value % product.gemsPerUnit != 0
          ? 'عدد الجواهر يجب أن يكون من مضاعفات ${product.gemsPerUnit}'
          : null,
    );
  }

  CalculationDraft updateUnits(CalculationDraft draft, int value) {
    final product = _requireGemProduct(draft.request.product);
    final units = value < 0 ? 0 : value;
    return _recalculateGemSale(
      draft,
      units: units,
      gems: units * product.gemsPerUnit,
    );
  }

  CalculationDraft updateSalePrice(CalculationDraft draft, int value) {
    if (draft.request.mode == CalculationMode.credit ||
        draft.request.mode == CalculationMode.directProduct) {
      final charged = value < 0 ? 0 : value;
      return draft.copyWith(
        salePrice: value,
        chargedAmount: charged,
        customerPaid: charged,
        customerChange: 0,
      );
    }
    return _recalculateGemSale(draft, salePrice: value);
  }

  CalculationDraft updateCustomerChange(CalculationDraft draft, int value) {
    if (draft.request.mode != CalculationMode.customerAmount) return draft;
    final charged = draft.customerPaid - value;
    final salePrice = draft.units == 0 ? 0 : charged ~/ draft.units;
    return draft.copyWith(
      customerChange: value,
      chargedAmount: charged,
      salePrice: salePrice,
    );
  }

  CalculationDraft updateInventoryCreditUsed(
    CalculationDraft draft,
    int value,
  ) {
    final previousInventory = draft.inventoryCreditUsed;
    final nextInventoryCost = previousInventory <= 0
        ? 0
        : ((draft.inventoryCostUsed * value) / previousInventory).round();
    final request = CalculationRequest(
      mode: draft.request.mode,
      product: draft.request.product,
      inputValue: draft.request.inputValue,
      useInventory: value > 0,
    );
    return _withAutomaticPlan(
      draft.copyWith(
        request: request,
        inventoryCreditUsed: value,
        inventoryCostUsed: nextInventoryCost < 0 ? 0 : nextInventoryCost,
      ),
    );
  }

  CalculationDraft setPackageQuantity(
    CalculationDraft draft,
    String packageId,
    int quantity,
  ) {
    final package = draft.packages.cast<CreditPackage?>().firstWhere(
      (item) => item?.id == packageId,
      orElse: () => null,
    );
    if (package == null) {
      throw const CalculationDraftValidationException([
        CalculationValidationIssue(
          code: 'package_not_registered',
          messageAr: 'يمكن استخدام الباقات المسجلة في التطبيق فقط.',
          messageFr:
              'Seuls les forfaits enregistrés dans l’application sont autorisés.',
        ),
      ]);
    }
    if (quantity < 0) {
      throw const CalculationDraftValidationException([
        CalculationValidationIssue(
          code: 'package_quantity_negative',
          messageAr: 'عدد الباقات لا يمكن أن يكون سالبًا.',
          messageFr: 'La quantité de forfaits ne peut pas être négative.',
        ),
      ]);
    }
    final quantities = <String, int>{
      for (final selection in draft.optimization?.selections ?? const [])
        selection.package.id: selection.quantity,
    };
    if (quantity == 0) {
      quantities.remove(packageId);
    } else {
      quantities[packageId] = quantity;
    }
    return replacePackagePlan(draft, quantities);
  }

  CalculationDraft incrementPackage(CalculationDraft draft, String packageId) {
    final current =
        draft.optimization?.selections
            .where((item) => item.package.id == packageId)
            .fold<int>(0, (sum, item) => sum + item.quantity) ??
        0;
    return setPackageQuantity(draft, packageId, current + 1);
  }

  CalculationDraft decrementPackage(CalculationDraft draft, String packageId) {
    final current =
        draft.optimization?.selections
            .where((item) => item.package.id == packageId)
            .fold<int>(0, (sum, item) => sum + item.quantity) ??
        0;
    return setPackageQuantity(draft, packageId, current <= 1 ? 0 : current - 1);
  }

  CalculationDraft removePackage(CalculationDraft draft, String packageId) =>
      setPackageQuantity(draft, packageId, 0);

  CalculationDraft replacePackagePlan(
    CalculationDraft draft,
    Map<String, int> quantities,
  ) {
    final registered = {for (final item in draft.packages) item.id: item};
    final selections = <PackageSelection>[];
    for (final entry in quantities.entries) {
      final package = registered[entry.key];
      if (package == null) {
        throw const CalculationDraftValidationException([
          CalculationValidationIssue(
            code: 'package_not_registered',
            messageAr: 'يمكن استخدام الباقات المسجلة في التطبيق فقط.',
            messageFr:
                'Seuls les forfaits enregistrés dans l’application sont autorisés.',
          ),
        ]);
      }
      if (entry.value < 0) {
        throw const CalculationDraftValidationException([
          CalculationValidationIssue(
            code: 'package_quantity_negative',
            messageAr: 'عدد الباقات لا يمكن أن يكون سالبًا.',
            messageFr: 'La quantité de forfaits ne peut pas être négative.',
          ),
        ]);
      }
      if (entry.value > 0) {
        selections.add(
          PackageSelection(package: package, quantity: entry.value),
        );
      }
    }
    selections.sort((a, b) => b.package.credit.compareTo(a.package.credit));
    final optimization = _buildOptimization(
      requiredCredit: draft.additionalCreditRequired,
      selections: selections,
    );
    return draft.copyWith(
      optimization: optimization,
      clearOptimization: selections.isEmpty,
    );
  }

  List<CalculationValidationIssue> validate(CalculationDraft draft) {
    final issues = <CalculationValidationIssue>[];
    if (draft.primaryInput != CalculationPrimaryInput.directProduct &&
        draft.primaryInputValue <= 0) {
      issues.add(
        const CalculationValidationIssue(
          code: 'primary_input_invalid',
          messageAr: 'المدخل الأساسي يجب أن يكون أكبر من صفر.',
          messageFr: "La valeur principale doit être supérieure à zéro.",
        ),
      );
    }
    if (draft.units < 0 ||
        draft.gems < 0 ||
        draft.salePrice < 0 ||
        draft.customerPaid < 0 ||
        draft.chargedAmount < 0 ||
        draft.customerChange < 0 ||
        draft.requiredCredit < 0) {
      issues.add(
        const CalculationValidationIssue(
          code: 'negative_value',
          messageAr: 'لا يمكن استخدام أرقام سالبة في العملية.',
          messageFr: "Les valeurs négatives ne sont pas autorisées.",
        ),
      );
    }
    if (draft.customerChange > draft.customerPaid) {
      issues.add(
        const CalculationValidationIssue(
          code: 'change_exceeds_paid',
          messageAr: 'المبلغ المعاد لا يمكن أن يكون أكبر من المبلغ المدفوع.',
          messageFr: "Le montant rendu ne peut pas dépasser le montant payé.",
        ),
      );
    }
    if (draft.inventoryCreditUsed < 0 ||
        draft.inventoryCreditUsed > draft.availableInventoryCredit ||
        draft.inventoryCreditUsed > draft.requiredCredit) {
      issues.add(
        const CalculationValidationIssue(
          code: 'inventory_out_of_range',
          messageAr: 'الرصيد المستخدم من المخزون خارج المجال المتاح.',
          messageFr: "Le crédit utilisé dépasse le stock disponible.",
        ),
      );
    }
    final product = draft.request.product;
    if ((draft.request.mode == CalculationMode.customerAmount ||
            draft.request.mode == CalculationMode.gems) &&
        product != null &&
        product.gemsPerUnit > 0 &&
        draft.gems % product.gemsPerUnit != 0) {
      issues.add(
        CalculationValidationIssue(
          code: 'gems_not_multiple',
          messageAr:
              'عدد الجواهر يجب أن يكون من مضاعفات ${product.gemsPerUnit}.',
          messageFr:
              'Le nombre de gemmes doit être un multiple de ${product.gemsPerUnit}.',
        ),
      );
    }
    final selections =
        draft.optimization?.selections ?? const <PackageSelection>[];
    final packageCount = selections.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    if (selections.any((item) => item.quantity <= 0 || item.quantity > 999) ||
        packageCount > 9999) {
      issues.add(
        const CalculationValidationIssue(
          code: 'package_quantity_invalid',
          messageAr: 'عدد الحزم أو الباقات غير منطقي.',
          messageFr: 'Le nombre de lots ou de forfaits est incohérent.',
        ),
      );
    }
    final registeredIds = draft.packages.map((item) => item.id).toSet();
    if (selections.any((item) => !registeredIds.contains(item.package.id))) {
      issues.add(
        const CalculationValidationIssue(
          code: 'package_not_registered',
          messageAr: 'تحتوي الخطة على باقة غير مسجلة في التطبيق.',
          messageFr:
              'Le plan contient un forfait non enregistré dans l’application.',
        ),
      );
    }
    if (draft.additionalCreditRequired > 0 &&
        draft.purchasedCredit < draft.additionalCreditRequired) {
      issues.add(
        const CalculationValidationIssue(
          code: 'package_plan_insufficient',
          messageAr: 'خطة الباقات لا تغطي الرصيد المطلوب شراؤه.',
          messageFr: 'Le plan de forfaits ne couvre pas le crédit à acheter.',
        ),
      );
    }
    if (draft.requiredCredit <= 0) {
      issues.add(
        const CalculationValidationIssue(
          code: 'required_credit_invalid',
          messageAr: 'لا يمكن حفظ عملية بلا رصيد مطلوب.',
          messageFr: "L’opération doit nécessiter un crédit positif.",
        ),
      );
    }
    if (!draft.marginPercent.isFinite) {
      issues.add(
        const CalculationValidationIssue(
          code: 'financial_result_invalid',
          messageAr: 'تعذر حساب النتيجة المالية للعملية.',
          messageFr: "Le résultat financier ne peut pas être calculé.",
        ),
      );
    }
    return List<CalculationValidationIssue>.unmodifiable(issues);
  }

  CalculationResult finalize(CalculationDraft draft) {
    final issues = validate(draft);
    if (issues.isNotEmpty) throw CalculationDraftValidationException(issues);
    return CalculationResult(
      request: draft.request,
      units: draft.units,
      gems: draft.gems,
      customerPaid: draft.customerPaid,
      chargedAmount: draft.chargedAmount,
      customerChange: draft.customerChange,
      requiredCredit: draft.requiredCredit,
      inventoryCreditUsed: draft.inventoryCreditUsed,
      additionalCreditRequired: draft.additionalCreditRequired,
      optimization: draft.optimization,
      creditCostUsed: draft.creditCostUsed,
      cashProfit: draft.cashProfit,
      warning: draft.warning,
    );
  }

  CalculationDraft _recalculateGemSale(
    CalculationDraft draft, {
    int? units,
    int? gems,
    int? salePrice,
    String? warning,
  }) {
    final product = _requireGemProduct(draft.request.product);
    final nextUnits = units ?? draft.units;
    final nextGems = gems ?? nextUnits * product.gemsPerUnit;
    final nextSalePrice = salePrice ?? draft.salePrice;
    final charged = nextUnits * nextSalePrice;
    final paid = draft.request.mode == CalculationMode.customerAmount
        ? draft.request.inputValue
        : charged;
    final change = draft.request.mode == CalculationMode.customerAmount
        ? paid - charged
        : 0;
    final required = nextUnits * product.creditPerUnit;
    final inventory = _min3(
      draft.inventoryCreditUsed,
      draft.availableInventoryCredit,
      required,
    );
    final nextInventoryCost = draft.inventoryCreditUsed <= 0
        ? 0
        : ((draft.inventoryCostUsed * inventory) / draft.inventoryCreditUsed)
              .round();
    return _withAutomaticPlan(
      draft.copyWith(
        units: nextUnits,
        gems: nextGems,
        salePrice: nextSalePrice,
        customerPaid: paid,
        chargedAmount: charged,
        customerChange: change,
        requiredCredit: required,
        inventoryCreditUsed: inventory,
        inventoryCostUsed: nextInventoryCost,
        warning: warning,
        clearWarning: warning == null,
      ),
    );
  }

  CalculationDraft _withAutomaticPlan(CalculationDraft draft) {
    final additional = draft.additionalCreditRequired;
    if (additional <= 0) {
      return draft.copyWith(clearOptimization: true);
    }
    final optimization = optimizer.optimize(
      requiredCredit: additional,
      packages: draft.packages,
    );
    return draft.copyWith(optimization: optimization);
  }

  OptimizationResult _buildOptimization({
    required int requiredCredit,
    required List<PackageSelection> selections,
  }) {
    final totalCredit = selections.fold<int>(
      0,
      (sum, item) => sum + item.totalCredit,
    );
    final totalCost = selections.fold<int>(
      0,
      (sum, item) => sum + item.totalCost,
    );
    final minimumValidity = selections.isEmpty
        ? 0
        : selections
              .map((item) => item.package.validityHours)
              .reduce((a, b) => a < b ? a : b);
    return OptimizationResult(
      requiredCredit: requiredCredit,
      selections: List<PackageSelection>.unmodifiable(selections),
      totalCost: totalCost,
      totalCredit: totalCredit,
      minimumValidityHours: minimumValidity,
    );
  }

  int _initialInventoryCost(
    CalculationResult result, {
    required List<CreditPackage> packages,
  }) {
    if (result.inventoryCreditUsed <= 0) return 0;
    final draft = CalculationDraft(
      request: result.request,
      availableInventoryCredit: result.inventoryCreditUsed,
      packages: packages,
      units: result.units,
      gems: result.gems,
      salePrice: 0,
      customerPaid: result.customerPaid,
      chargedAmount: result.chargedAmount,
      customerChange: result.customerChange,
      requiredCredit: result.requiredCredit,
      inventoryCreditUsed: result.inventoryCreditUsed,
      inventoryCostUsed: 0,
      optimization: result.optimization,
    );
    final cost = result.creditCostUsed - draft.packageCreditCostUsed;
    return cost < 0 ? 0 : cost;
  }

  Product _requireGemProduct(Product? product) {
    if (product == null || product.type != ProductType.gems) {
      throw ArgumentError('منتج الجواهر مطلوب');
    }
    return product;
  }

  int _min3(int first, int second, int third) {
    var result = first;
    if (second < result) result = second;
    if (third < result) result = third;
    return result < 0 ? 0 : result;
  }
}
