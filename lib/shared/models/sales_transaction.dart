import 'calculation.dart';

class SalesTransaction {
  const SalesTransaction({
    required this.id,
    required this.createdAt,
    required this.customerName,
    required this.mode,
    this.productId,
    this.productNameSnapshot,
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
    required this.cashProfit,
  });

  final String id;
  final DateTime createdAt;
  final String customerName;
  final CalculationMode mode;
  final String? productId;
  final String? productNameSnapshot;
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
  final int cashProfit;

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'customer_name': customerName,
        'mode': mode.name,
        'product_id': productId,
        'product_name_snapshot': productNameSnapshot,
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
        'cash_profit': cashProfit,
      };

  factory SalesTransaction.fromMap(Map<String, Object?> map) {
    final rawCustomerName = map['customer_name'] as String?;
    final customerName = rawCustomerName == null || rawCustomerName.trim().isEmpty
        ? 'عميل سابق'
        : rawCustomerName.trim();

    return SalesTransaction(
      id: map['id']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      customerName: customerName,
      mode: CalculationMode.values.byName(map['mode']! as String),
      productId: map['product_id'] as String?,
      productNameSnapshot: map['product_name_snapshot'] as String?,
      inputValue: map['input_value']! as int,
      useInventory: (map['use_inventory']! as int) == 1,
      units: map['units']! as int,
      gems: map['gems']! as int,
      customerPaid: map['customer_paid']! as int,
      chargedAmount: map['charged_amount']! as int,
      customerChange: map['customer_change']! as int,
      requiredCredit: map['required_credit']! as int,
      inventoryCreditUsed: map['inventory_credit_used']! as int,
      additionalCreditRequired: map['additional_credit_required']! as int,
      purchasedCredit: map['purchased_credit']! as int,
      newPackagesCost: map['new_packages_cost']! as int,
      cashProfit: map['cash_profit']! as int,
    );
  }
}
