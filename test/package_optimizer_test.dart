import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/package_optimizer.dart';
import 'package:game_credit_profit_manager/shared/models/credit_package.dart';

import 'test_fixtures.dart';

void main() {
  const optimizer = PackageOptimizer();

  test('2400 رصيد = 2000 + 400 بتكلفة 2500 وفائض صفر', () {
    final result = optimizer.optimize(
      requiredCredit: 2400,
      packages: defaultPackages,
    );

    expect(result.totalCredit, 2400);
    expect(result.totalCost, 2500);
    expect(result.excessCredit, 0);
    expect(
      {for (final item in result.selections) item.package.id: item.quantity},
      {'pkg_2000': 1, 'pkg_400': 1},
    );
  });

  test('عند تساوي التكلفة والفائض يختار أقل عدد من الباقات', () {
    const packages = [
      CreditPackage(
        id: 'small',
        name: '100',
        priceDzd: 100,
        credit: 100,
        validityHours: 24,
      ),
      CreditPackage(
        id: 'large',
        name: '200',
        priceDzd: 200,
        credit: 200,
        validityHours: 48,
      ),
    ];

    final result = optimizer.optimize(requiredCredit: 200, packages: packages);

    expect(result.packageCount, 1);
    expect(result.selections.single.package.id, 'large');
  });

  test('عند استمرار التعادل يفضل الصلاحية الأطول', () {
    const packages = [
      CreditPackage(
        id: 'short',
        name: 'قصيرة',
        priceDzd: 100,
        credit: 100,
        validityHours: 24,
      ),
      CreditPackage(
        id: 'long',
        name: 'طويلة',
        priceDzd: 100,
        credit: 100,
        validityHours: 72,
      ),
    ];

    final result = optimizer.optimize(requiredCredit: 100, packages: packages);

    expect(result.selections.single.package.id, 'long');
    expect(result.minimumValidityHours, 72);
  });

  test('تعديل أسعار الباقات يغير النتيجة دون شروط ثابتة', () {
    final changed = [
      ...defaultPackages.where((item) => item.id != 'pkg_3000'),
      const CreditPackage(
        id: 'pkg_3000',
        name: 'باقة 3000 مخفضة',
        priceDzd: 1000,
        credit: 3000,
        validityHours: 720,
      ),
    ];

    final result = optimizer.optimize(requiredCredit: 2400, packages: changed);

    expect(result.totalCost, 1000);
    expect(result.totalCredit, 3000);
    expect(result.selections.single.package.id, 'pkg_3000');
  });
}
