import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/calculation_draft_engine.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';

import 'test_fixtures.dart';

void main() {
  const engine = CalculationDraftEngine();

  group('customizable calculation draft', () {
    test('keeps 6000 DZD primary input fixed when gems change', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.customerAmount,
          product: defaultProduct,
          inputValue: 6000,
          useInventory: true,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updateGems(draft, 1600);

      expect(updated.primaryInput, CalculationPrimaryInput.customerAmount);
      expect(updated.primaryInputValue, 6000);
      expect(updated.customerPaid, 6000);
      expect(updated.units, 16);
      expect(updated.gems, 1600);
      expect(updated.requiredCredit, 3840);
      expect(updated.chargedAmount, 5600);
      expect(updated.customerChange, 50);
      expect(updated.salePrice, 350);
    });

    test(
      'changing gems keeps paid amount, returned amount, and package price fixed',
      () {
        final draft = engine.create(
          request: const CalculationRequest(
            mode: CalculationMode.customerAmount,
            product: defaultProduct,
            inputValue: 5000,
            useInventory: false,
          ),
          packages: defaultPackages,
          availableInventoryCredit: 0,
        );

        expect(draft.customerPaid, 5000);
        expect(draft.customerChange, 100);
        expect(draft.chargedAmount, 4900);
        expect(draft.salePrice, 350);

        final updated = engine.updateGems(draft, 1500);

        expect(updated.primaryInputValue, 5000);
        expect(updated.customerPaid, 5000);
        expect(updated.customerChange, 100);
        expect(updated.salePrice, 350);
        expect(updated.gems, 1500);
        expect(updated.units, 15);
        expect(updated.chargedAmount, 5250);
        expect(updated.cashProfit, isNot(draft.cashProfit));
        expect(updated.marginPercent, isNot(draft.marginPercent));
      },
    );

    test(
      'editing returned amount does not rewrite calculated amount or price',
      () {
        final draft = engine.create(
          request: const CalculationRequest(
            mode: CalculationMode.customerAmount,
            product: defaultProduct,
            inputValue: 5000,
            useInventory: false,
          ),
          packages: defaultPackages,
          availableInventoryCredit: 0,
        );

        final updated = engine.updateCustomerChange(draft, 200);

        expect(updated.customerPaid, 5000);
        expect(updated.customerChange, 200);
        expect(updated.chargedAmount, 4900);
        expect(updated.salePrice, 350);
      },
    );

    test('package sale price cannot be changed from the result draft', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.customerAmount,
          product: defaultProduct,
          inputValue: 5000,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updateSalePrice(draft, 999);

      expect(updated.salePrice, 350);
      expect(updated.chargedAmount, 4900);
      expect(updated.customerPaid, 5000);
      expect(updated.customerChange, 100);
    });

    test('editing the amount primary input recalculates all dependents', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.customerAmount,
          product: defaultProduct,
          inputValue: 6000,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updatePrimaryInput(draft, 7000);

      expect(updated.primaryInputValue, 7000);
      expect(updated.units, 20);
      expect(updated.gems, 2000);
      expect(updated.requiredCredit, 4800);
      expect(updated.chargedAmount, 7000);
      expect(updated.customerChange, 0);
    });

    test('gems operation treats gems as the primary input', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.gems,
          product: defaultProduct,
          inputValue: 1700,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updatePrimaryInput(draft, 1800);

      expect(updated.primaryInput, CalculationPrimaryInput.gems);
      expect(updated.primaryInputValue, 1800);
      expect(updated.units, 18);
      expect(updated.gems, 1800);
      expect(updated.requiredCredit, 4320);
      expect(updated.chargedAmount, 6300);
    });

    test('credit operation treats required credit as the primary input', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.credit,
          inputValue: 4800,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updatePrimaryInput(draft, 5000);

      expect(updated.primaryInput, CalculationPrimaryInput.credit);
      expect(updated.primaryInputValue, 5000);
      expect(updated.requiredCredit, 5000);
      expect(updated.purchasedCredit, greaterThanOrEqualTo(5000));
      expect(updated.chargedAmount, greaterThan(0));
    });

    test('invalid returned amount is reported in Arabic and French', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.customerAmount,
          product: defaultProduct,
          inputValue: 6000,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updateCustomerChange(draft, 6001);
      final issues = engine.validate(updated);

      expect(
        issues.map((issue) => issue.code),
        contains('change_exceeds_paid'),
      );
      final issue = issues.firstWhere(
        (item) => item.code == 'change_exceeds_paid',
      );
      expect(issue.messageAr, isNotEmpty);
      expect(issue.messageFr, isNotEmpty);
    });
  });
}
