import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/shared/models/sales_transaction.dart';

void main() {
  Map<String, Object?> transactionRow({
    String? customerId,
    String? customerName,
  }) => {
    'id': 'txn_1',
    'created_at': '2026-07-12T10:00:00.000',
    if (customerId != null) 'customer_id': customerId,
    if (customerName != null) 'customer_name': customerName,
    'mode': 'gems',
    'product_id': 'product_100_gems',
    'product_name_snapshot': '100 جوهرة',
    'input_value': 100,
    'use_inventory': 1,
    'units': 1,
    'gems': 100,
    'customer_paid': 350,
    'charged_amount': 350,
    'customer_change': 0,
    'required_credit': 240,
    'inventory_credit_used': 240,
    'additional_credit_required': 0,
    'purchased_credit': 0,
    'new_packages_cost': 0,
    'cash_profit': 350,
  };

  test('يحفظ هوية واسم العميل ويعيد قراءتهما', () {
    final transaction = SalesTransaction.fromMap(
      transactionRow(customerId: 'customer_1', customerName: '  محمد أمين  '),
    );

    expect(transaction.customerId, 'customer_1');
    expect(transaction.customerName, 'محمد أمين');
    expect(transaction.toMap()['customer_id'], 'customer_1');
    expect(transaction.toMap()['customer_name'], 'محمد أمين');
  });

  test('يمنح العمليات القديمة اسمًا احتياطيًا', () {
    final transaction = SalesTransaction.fromMap(transactionRow());

    expect(transaction.customerId, isNull);
    expect(transaction.customerName, 'عميل سابق');
  });
}
