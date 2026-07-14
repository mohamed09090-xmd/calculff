import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/calculation_draft_engine.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';

import 'test_fixtures.dart';

void main() {
  const engine = CalculationDraftEngine();

  group('locked primary input and manual calculated amount', () {
    test('changing gems keeps amount primary and calculated amount fixed', () {
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
      expect(updated.chargedAmount, draft.chargedAmount);
      expect(updated.customerChange, draft.customerChange);
      expect(updated.salePrice, draft.salePrice);
    });

    test(
      'changing units never changes the calculated amount automatically',
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

        final updated = engine.updateUnits(draft, 15);

        expect(updated.units, 15);
        expect(updated.gems, 1500);
        expect(updated.requiredCredit, 3600);
        expect(updated.chargedAmount, draft.chargedAmount);
        expect(updated.primaryInputValue, 5000);
      },
    );

    test('amount primary input cannot be edited', () {
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

      expect(engine.updatePrimaryInput(draft, 7000), same(draft));
    });

    test('gems primary input cannot be edited directly or through units', () {
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

      expect(engine.updatePrimaryInput(draft, 1800), same(draft));
      expect(engine.updateGems(draft, 1800), same(draft));
      expect(engine.updateUnits(draft, 18), same(draft));
    });

    test('credit primary input cannot be edited', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.credit,
          inputValue: 4800,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      expect(engine.updatePrimaryInput(draft, 5000), same(draft));
    });

    test('manual calculated amount changes profit and margin only', () {
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

      final updated = engine.updateCalculatedAmount(draft, 5250);

      expect(updated.request, same(draft.request));
      expect(updated.availableInventoryCredit, draft.availableInventoryCredit);
      expect(updated.packages, same(draft.packages));
      expect(updated.primaryInputValue, draft.primaryInputValue);
      expect(updated.units, draft.units);
      expect(updated.gems, draft.gems);
      expect(updated.salePrice, draft.salePrice);
      expect(updated.customerPaid, draft.customerPaid);
      expect(updated.customerChange, draft.customerChange);
      expect(updated.requiredCredit, draft.requiredCredit);
      expect(updated.inventoryCreditUsed, draft.inventoryCreditUsed);
      expect(updated.inventoryCostUsed, draft.inventoryCostUsed);
      expect(updated.optimization, same(draft.optimization));
      expect(updated.chargedAmount, 5250);
      expect(
        updated.cashProfit,
        draft.cashProfit + (5250 - draft.chargedAmount),
      );
      expect(updated.marginPercent, isNot(draft.marginPercent));
    });

    test('manual calculated amount is independent in gems mode', () {
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

      final updated = engine.updateCalculatedAmount(draft, 7000);

      expect(updated.primaryInputValue, 1700);
      expect(updated.gems, draft.gems);
      expect(updated.units, draft.units);
      expect(updated.requiredCredit, draft.requiredCredit);
      expect(updated.chargedAmount, 7000);
      expect(updated.cashProfit, isNot(draft.cashProfit));
    });

    test('manual calculated amount is independent in credit mode', () {
      final draft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.credit,
          inputValue: 4800,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      final updated = engine.updateCalculatedAmount(draft, 8000);

      expect(updated.primaryInputValue, 4800);
      expect(updated.requiredCredit, 4800);
      expect(updated.optimization, same(draft.optimization));
      expect(updated.chargedAmount, 8000);
      expect(updated.cashProfit, isNot(draft.cashProfit));
    });

    test('sale price cannot be changed from the result draft', () {
      final amountDraft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.customerAmount,
          product: defaultProduct,
          inputValue: 5000,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );
      final creditDraft = engine.create(
        request: const CalculationRequest(
          mode: CalculationMode.credit,
          inputValue: 4800,
          useInventory: false,
        ),
        packages: defaultPackages,
        availableInventoryCredit: 0,
      );

      expect(engine.updateSalePrice(amountDraft, 999), same(amountDraft));
      expect(engine.updateSalePrice(creditDraft, 999), same(creditDraft));
    });

    test('editing returned amount does not rewrite calculated amount', () {
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
      expect(updated.chargedAmount, draft.chargedAmount);
      expect(updated.salePrice, draft.salePrice);
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
