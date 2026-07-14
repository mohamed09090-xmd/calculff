import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/calculator/application/calculation_draft_engine.dart';
import 'package:game_credit_profit_manager/features/calculator/presentation/calculation_customization_editor.dart';
import 'package:game_credit_profit_manager/shared/models/app_settings.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';

import 'test_fixtures.dart';

void main() {
  const engine = CalculationDraftEngine();

  CalculationDraft amountDraft() => engine.create(
    request: const CalculationRequest(
      mode: CalculationMode.customerAmount,
      product: defaultProduct,
      inputValue: 6000,
      useInventory: false,
    ),
    packages: defaultPackages,
    availableInventoryCredit: 0,
  );

  CalculationDraft gemsDraft() => engine.create(
    request: const CalculationRequest(
      mode: CalculationMode.gems,
      product: defaultProduct,
      inputValue: 1700,
      useInventory: false,
    ),
    packages: defaultPackages,
    availableInventoryCredit: 0,
  );

  CalculationDraft creditDraft() => engine.create(
    request: const CalculationRequest(
      mode: CalculationMode.credit,
      inputValue: 4800,
      useInventory: false,
    ),
    packages: defaultPackages,
    availableInventoryCredit: 0,
  );

  Widget app({
    required CalculationDraft draft,
    required ValueChanged<CalculationDraft> onChanged,
    Locale locale = const Locale('ar'),
    double textScale = 1,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: CalculationCustomizationEditor(
              draft: draft,
              settings: AppSettings.defaults,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('amount primary input is read only', (tester) async {
    await tester.pumpWidget(app(draft: amountDraft(), onChanged: (_) {}));

    expect(
      find.byKey(const ValueKey('primary-input-readonly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('primary-input')), findsNothing);
    expect(find.textContaining('لا يمكن تعديلها'), findsOneWidget);
  });

  testWidgets('gems and credit primary inputs are read only', (tester) async {
    await tester.pumpWidget(app(draft: gemsDraft(), onChanged: (_) {}));
    expect(
      find.byKey(const ValueKey('primary-input-readonly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('primary-input')), findsNothing);

    await tester.pumpWidget(app(draft: creditDraft(), onChanged: (_) {}));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('primary-input-readonly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('primary-input')), findsNothing);
  });

  testWidgets('calculated amount is the manual financial input', (
    tester,
  ) async {
    var latest = amountDraft();
    final initial = latest;
    await tester.pumpWidget(
      app(draft: latest, onChanged: (value) => latest = value),
    );

    final field = find.descendant(
      of: find.byKey(const ValueKey('calculated-amount-input')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, '5250');
    await tester.pump();

    expect(latest.chargedAmount, 5250);
    expect(latest.primaryInputValue, initial.primaryInputValue);
    expect(latest.units, initial.units);
    expect(latest.gems, initial.gems);
    expect(latest.requiredCredit, initial.requiredCredit);
    expect(latest.customerPaid, initial.customerPaid);
    expect(latest.customerChange, initial.customerChange);
    expect(latest.salePrice, initial.salePrice);
    expect(latest.cashProfit, isNot(initial.cashProfit));
    expect(latest.marginPercent, isNot(initial.marginPercent));
  });

  testWidgets('editing gems does not change calculated amount automatically', (
    tester,
  ) async {
    var latest = amountDraft();
    final initialCharged = latest.chargedAmount;
    await tester.pumpWidget(
      app(draft: latest, onChanged: (value) => latest = value),
    );

    final field = find.descendant(
      of: find.byKey(const ValueKey('gems-input')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, '1600');
    await tester.pump();

    expect(latest.primaryInputValue, 6000);
    expect(latest.gems, 1600);
    expect(latest.units, 16);
    expect(latest.chargedAmount, initialCharged);
  });

  testWidgets('gem package sale price is read only and comes from settings', (
    tester,
  ) async {
    await tester.pumpWidget(app(draft: amountDraft(), onChanged: (_) {}));

    expect(find.byKey(const ValueKey('sale-price-input')), findsNothing);
    expect(find.text('سعر بيع الحزمة'), findsOneWidget);
    expect(find.textContaining('إعدادات المنتج فقط'), findsOneWidget);
  });

  testWidgets('supports small screens and large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(draft: amountDraft(), textScale: 2, onChanged: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('المدخل الأساسي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows French fixed-input and calculated-amount guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(draft: amountDraft(), locale: const Locale('fr'), onChanged: (_) {}),
    );

    expect(find.textContaining('Valeur fixe'), findsOneWidget);
    expect(find.textContaining('uniquement le bénéfice'), findsOneWidget);
  });
}
