import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/calculation_draft_engine.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';
import 'package:game_credit_profit_manager/shared/models/credit_package.dart';

const planPackages = <CreditPackage>[
  CreditPackage(
    id: 'pkg_250',
    name: 'باقة 250 رصيد',
    priceDzd: 300,
    credit: 250,
    validityHours: 24,
  ),
  CreditPackage(
    id: 'pkg_1000',
    name: 'باقة 1000 رصيد',
    priceDzd: 1000,
    credit: 1000,
    validityHours: 48,
  ),
  CreditPackage(
    id: 'pkg_2000',
    name: 'باقة 2000 رصيد',
    priceDzd: 1800,
    credit: 2000,
    validityHours: 72,
  ),
];

void main() {
  const engine = CalculationDraftEngine();

  CalculationDraft createDraft({int availableInventory = 0}) => engine.create(
    request: const CalculationRequest(
      mode: CalculationMode.credit,
      inputValue: 2000,
      useInventory: true,
    ),
    packages: planPackages,
    availableInventoryCredit: availableInventory,
  );

  group('custom package plan and inventory', () {
    test('replaces 1x2000 with 2x1000 plus 1x250', () {
      final initial = createDraft();
      expect(
        {
          for (final item in initial.optimization!.selections)
            item.package.id: item.quantity,
        },
        {'pkg_2000': 1},
      );

      final customized = engine.replacePackagePlan(initial, const {
        'pkg_1000': 2,
        'pkg_250': 1,
      });

      expect(customized.purchasedCredit, 2250);
      expect(customized.remainingPurchasedCredit, 250);
      expect(customized.newPackagesCost, 2300);
      expect(customized.creditCostUsed, 2050);
      expect(customized.cashProfit, 870);
      expect(customized.marginPercent, closeTo(29.8, 0.1));
      expect(customized.optimization!.packageCount, 3);
      expect(engine.validate(customized), isEmpty);
    });

    test('inventory usage updates the credit that must be purchased', () {
      final draft = createDraft(availableInventory: 500);

      final customized = engine.updateInventoryCreditUsed(draft, 250);

      expect(customized.inventoryCreditUsed, 250);
      expect(customized.additionalCreditRequired, 1750);
      expect(customized.purchasedCredit, greaterThanOrEqualTo(1750));
    });

    test('surplus purchased credit remains available for stock', () {
      final customized = engine.replacePackagePlan(createDraft(), const {
        'pkg_1000': 2,
        'pkg_250': 1,
      });
      final result = engine.finalize(customized);

      expect(result.purchasedCredit, 2250);
      expect(result.additionalCreditRequired, 2000);
      expect(result.remainingPurchasedCredit, 250);
    });

    test('insufficient package plan prevents finalization', () {
      final customized = engine.replacePackagePlan(createDraft(), const {
        'pkg_1000': 1,
      });

      final issues = engine.validate(customized);
      expect(
        issues.map((issue) => issue.code),
        contains('package_plan_insufficient'),
      );
      expect(
        () => engine.finalize(customized),
        throwsA(isA<CalculationDraftValidationException>()),
      );
    });

    test('package quantity can be increased, reduced, and removed', () {
      var draft = createDraft();
      draft = engine.incrementPackage(draft, 'pkg_250');
      expect(
        draft.optimization!.selections
            .firstWhere((item) => item.package.id == 'pkg_250')
            .quantity,
        1,
      );
      draft = engine.incrementPackage(draft, 'pkg_250');
      draft = engine.decrementPackage(draft, 'pkg_250');
      expect(
        draft.optimization!.selections
            .firstWhere((item) => item.package.id == 'pkg_250')
            .quantity,
        1,
      );
      draft = engine.removePackage(draft, 'pkg_250');
      expect(
        draft.optimization!.selections.any(
          (item) => item.package.id == 'pkg_250',
        ),
        isFalse,
      );
    });

    test('inventory above available stock is rejected', () {
      final customized = engine.updateInventoryCreditUsed(
        createDraft(availableInventory: 500),
        501,
      );

      expect(
        engine.validate(customized).map((issue) => issue.code),
        contains('inventory_out_of_range'),
      );
    });
  });
}
