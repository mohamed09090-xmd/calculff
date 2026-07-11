import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/calculation_engine.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';

import 'test_fixtures.dart';

void main() {
  const engine = CalculationEngine();

  test('سيناريو العميل 6000 دج يطابق النتيجة الإلزامية حرفيًا', () {
    final result = engine.calculate(
      request: const CalculationRequest(
        mode: CalculationMode.customerAmount,
        product: defaultProduct,
        inputValue: 6000,
        useInventory: true,
      ),
      packages: defaultPackages,
      availableInventoryCredit: 0,
    );

    expect(result.units, 17);
    expect(result.gems, 1700);
    expect(result.chargedAmount, 5950);
    expect(result.customerChange, 50);
    expect(result.requiredCredit, 4080);
    expect(result.purchasedCredit, 4110);
    expect(result.newPackagesCost, 4150);
    expect(result.remainingPurchasedCredit, 30);
    expect(result.cashProfit, 1800);
    expect(
      {for (final item in result.optimization!.selections) item.package.id: item.quantity},
      {'pkg_2000': 2, 'pkg_110': 1},
    );
  });

  test('مبلغ أقل من 350 لا ينشئ حزمة ويعيد المبلغ كاملًا', () {
    final result = engine.calculate(
      request: const CalculationRequest(
        mode: CalculationMode.customerAmount,
        product: defaultProduct,
        inputValue: 349,
        useInventory: true,
      ),
      packages: defaultPackages,
      availableInventoryCredit: 0,
    );

    expect(result.units, 0);
    expect(result.gems, 0);
    expect(result.requiredCredit, 0);
    expect(result.customerChange, 349);
    expect(result.warning, isNotNull);
  });

  test('رصيد المخزون يغطي العملية بالكامل', () {
    final result = engine.calculate(
      request: const CalculationRequest(
        mode: CalculationMode.customerAmount,
        product: defaultProduct,
        inputValue: 350,
        useInventory: true,
      ),
      packages: defaultPackages,
      availableInventoryCredit: 240,
    );

    expect(result.inventoryCreditUsed, 240);
    expect(result.additionalCreditRequired, 0);
    expect(result.optimization, isNull);
    expect(result.newPackagesCost, 0);
    expect(result.cashProfit, 350);
  });

  test('رصيد المخزون يغطي جزءًا من العملية', () {
    final result = engine.calculate(
      request: const CalculationRequest(
        mode: CalculationMode.customerAmount,
        product: defaultProduct,
        inputValue: 350,
        useInventory: true,
      ),
      packages: defaultPackages,
      availableInventoryCredit: 100,
    );

    expect(result.inventoryCreditUsed, 100);
    expect(result.additionalCreditRequired, 140);
    expect(result.purchasedCredit, 200);
    expect(result.newPackagesCost, 250);
    expect(result.remainingPurchasedCredit, 60);
  });

  test('عدد جواهر غير متوافق يظهر اقتراحًا ولا يرفع الكمية تلقائيًا', () {
    final result = engine.calculate(
      request: const CalculationRequest(
        mode: CalculationMode.gems,
        product: defaultProduct,
        inputValue: 1750,
        useInventory: false,
      ),
      packages: defaultPackages,
      availableInventoryCredit: 0,
    );

    expect(result.units, 17);
    expect(result.gems, 1700);
    expect(result.warning, contains('1700'));
    expect(result.warning, contains('1800'));
  });
}
