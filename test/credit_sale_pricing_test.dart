import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/credit_sale_pricing.dart';

void main() {
  const pricing = CreditSalePricing(
    referenceCredit: 240,
    referencePriceDzd: 350,
  );

  test('يستخدم قاعدة 240 رصيد مقابل 350 دج', () {
    expect(pricing.priceFor(240), 350);
    expect(pricing.priceFor(480), 700);
  });

  test('يقرب سعر البيع إلى أقرب 10 دج', () {
    expect(pricing.priceFor(100), 150);
    expect(pricing.priceFor(600), 880);
    expect(pricing.priceFor(1000), 1460);
  });

  test('يرجع صفرًا لكمية غير موجبة', () {
    expect(pricing.priceFor(0), 0);
    expect(pricing.priceFor(-10), 0);
  });
}
