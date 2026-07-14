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
  int get cashProfit => chargedAmount - newPackagesCost;
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

  List<CalculationValidationIssue> validate(CalculationDraft draft) {
    final issues = <CalculationValidationIssue>[];
    if (draft.primaryInput != CalculationPrimaryInput.directProduct &&
        draft.primaryInputValue <= 0) {
      issues.add(
        const CalculationValidationIssue(
          code: 'primary_input_invalid',
          messageAr: 'المدخل الأساسي يجب أن يكون أكبر من صفر.',
          messageFr: 'La valeur principale doit être supérieure à zéro.',
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
          messageFr: 'Les valeurs négatives ne sont pas autorisées.',
        ),
      );
    }
    if (draft.customerChange > draft.customerPaid) {
      issues.add(
        const CalculationValidationIssue(
          code: 'change_exceeds_paid',
          messageAr: 'المبلغ المعاد لا يمكن أن يكون أكبر من المبلغ المدفوع.',
          messageFr: 'Le montant rendu ne peut pas dépasser le montant payé.',
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
          messageFr: 'Le crédit utilisé dépasse le stock disponible.',
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
    if (draft.requiredCredit <= 0) {
      issues.add(
        const CalculationValidationIssue(
          code: 'required_credit_invalid',
          messageAr: 'لا يمكن حفظ عملية بلا رصيد مطلوب.',
          messageFr: 'L’opération doit nécessiter un crédit positif.',
        ),
      );
    }
    if (!draft.marginPercent.isFinite) {
      issues.add(
        const CalculationValidationIssue(
          code: 'financial_result_invalid',
          messageAr: 'تعذر حساب النتيجة المالية للعملية.',
          messageFr: 'Le résultat financier ne peut pas être calculé.',
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
      creditCostUsed: draft.newPackagesCost,
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
    final additional = required - inventory;
    final optimization = additional == 0
        ? null
        : optimizer.optimize(
            requiredCredit: additional,
            packages: draft.packages,
          );
    return draft.copyWith(
      units: nextUnits,
      gems: nextGems,
      salePrice: nextSalePrice,
      customerPaid: paid,
      chargedAmount: charged,
      customerChange: change,
      requiredCredit: required,
      inventoryCreditUsed: inventory,
      optimization: optimization,
      clearOptimization: optimization == null,
      warning: warning,
      clearWarning: warning == null,
    );
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
