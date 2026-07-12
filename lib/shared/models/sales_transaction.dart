import 'calculation.dart';

class SalesTransaction {
  const SalesTransaction({
    required this.id,
    required this.createdAt,
    required this.customerId,
    required this.customerName,
    required this.mode,
    this.productId,
    this.productNameSnapshot,
    this.productDescriptionSnapshot,
    required this.inputValue,
    required this.useInventory,
    required this.units,
    required this.gems,
    required this.customerPaid,
    required this.chargedAmount,
    required this.customerChange,
    required this.requiredCredit,
    required this.inventoryCreditUsed,
    required this.additionalCreditRequired,
    required this.purchasedCredit,
    required this.newPackagesCost,
    this.creditCostUsed = 0,
    required this.cashProfit,
  });

  final String id;
  final DateTime createdAt;
  final String? customerId;
  final String customerName;
  final CalculationMode mode;
  final String? productId;
  final String? productNameSnapshot;
  final String? productDescriptionSnapshot;
  final int inputValue;
  final bool useInventory;
  final int units;
  final int gems;
  final int customerPaid;
  final int chargedAmount;
  final int customerChange;
  final int requiredCredit;
  final int inventoryCreditUsed;
  final int additionalCreditRequired;
  final int purchasedCredit;
  final int newPackagesCost;
  final int creditCostUsed;
  final int cashProfit;

  String get displayProductName =>
      productNameSnapshot ??
      (mode == CalculationMode.credit ? 'بيع رصيد مباشر' : 'عملية رصيد');

  Map<String, Object?> toMap() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'customer_id': customerId,
    'customer_name': customerName,
    'mode': mode.name,
    'product_id': productId,
    'product_name_snapshot': productNameSnapshot,
    'product_description_snapshot': productDescriptionSnapshot,
    'input_value': inputValue,
    'use_inventory': useInventory ? 1 : 0,
    'units': units,
    'gems': gems,
    'customer_paid': customerPaid,
    'charged_amount': chargedAmount,
    'customer_change': customerChange,
    'required_credit': requiredCredit,
    'inventory_credit_used': inventoryCreditUsed,
    'additional_credit_required': additionalCreditRequired,
    'purchased_credit': purchasedCredit,
    'new_packages_cost': newPackagesCost,
    'credit_cost_used': creditCostUsed,
    'cash_profit': cashProfit,
  };

  factory SalesTransaction.fromMap(Map<String, Object?> map) {
    final rawCustomerName = map['customer_name'] as String?;
    final customerName =
        rawCustomerName == null || rawCustomerName.trim().isEmpty
        ? 'عميل سابق'
        : rawCustomerName.trim();
    final chargedAmount = (map['charged_amount'] as num).toInt();
    final cashProfit = (map['cash_profit'] as num).toInt();
    final rawCreditCost = (map['credit_cost_used'] as num?)?.toInt();

    return SalesTransaction(
      id: map['id']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      customerId: map['customer_id'] as String?,
      customerName: customerName,
      mode: CalculationMode.values.byName(map['mode']! as String),
      productId: map['product_id'] as String?,
      productNameSnapshot: map['product_name_snapshot'] as String?,
      productDescriptionSnapshot:
          map['product_description_snapshot'] as String?,
      inputValue: (map['input_value'] as num).toInt(),
      useInventory: (map['use_inventory']! as int) == 1,
      units: (map['units'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
      customerPaid: (map['customer_paid'] as num).toInt(),
      chargedAmount: chargedAmount,
      customerChange: (map['customer_change'] as num).toInt(),
      requiredCredit: (map['required_credit'] as num).toInt(),
      inventoryCreditUsed: (map['inventory_credit_used'] as num).toInt(),
      additionalCreditRequired: (map['additional_credit_required'] as num)
          .toInt(),
      purchasedCredit: (map['purchased_credit'] as num).toInt(),
      newPackagesCost: (map['new_packages_cost'] as num).toInt(),
      creditCostUsed:
          rawCreditCost == null ||
              (rawCreditCost == 0 && chargedAmount != cashProfit)
          ? chargedAmount - cashProfit
          : rawCreditCost,
      cashProfit: cashProfit,
    );
  }
}
