import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/shared/models/customer.dart';

void main() {
  test('يقرأ بيانات العميل وإحصاءاته من الاستعلام المجمع', () {
    final customer = Customer.fromMap({
      'id': 'customer_1',
      'name': 'محمد',
      'phone': '0550000000',
      'notes': 'عميل دائم',
      'is_active': 1,
      'created_at': '2026-07-12T10:00:00.000',
      'updated_at': '2026-07-12T11:00:00.000',
      'transaction_count': 3,
      'total_spent': 1050,
      'total_profit': 420,
      'last_transaction_at': '2026-07-12T12:00:00.000',
    });

    expect(customer.name, 'محمد');
    expect(customer.transactionCount, 3);
    expect(customer.totalSpent, 1050);
    expect(customer.totalProfit, 420);
    expect(customer.lastTransactionAt, isNotNull);
  });

  test('ينظف الحقول الاختيارية الفارغة عند التحويل إلى خريطة', () {
    final customer = Customer(
      id: 'customer_2',
      name: 'إسلام',
      phone: '   ',
      notes: '',
      isActive: true,
      createdAt: DateTime(2026, 7, 12),
      updatedAt: DateTime(2026, 7, 12),
    );

    final map = customer.toMap();
    expect(map['phone'], isNull);
    expect(map['notes'], isNull);
  });
}
