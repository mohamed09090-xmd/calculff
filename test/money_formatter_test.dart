import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/utils/money_formatter.dart';

void main() {
  test('تحويل الدينار إلى صيغة الألف', () {
    expect(MoneyFormatter.thousands(150), '15 ألف');
    expect(MoneyFormatter.thousands(350), '35 ألف');
    expect(MoneyFormatter.thousands(6000), '600 ألف');
  });

  test('تحويل صيغة الألف إلى الدينار', () {
    expect(MoneyFormatter.thousandsToDinar(15), 150);
    expect(MoneyFormatter.thousandsToDinar(35), 350);
    expect(MoneyFormatter.thousandsToDinar(600), 6000);
  });
}
