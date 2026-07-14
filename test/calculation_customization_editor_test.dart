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

  testWidgets('keeps primary 6000 when gems are edited', (tester) async {
    var latest = amountDraft();
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

  testWidgets('shows French labels and validation messages', (tester) async {
    final invalid = engine.updateCustomerChange(amountDraft(), 6001);
    await tester.pumpWidget(
      app(draft: invalid, locale: const Locale('fr'), onChanged: (_) {}),
    );

    expect(find.text('Personnaliser l’opération'), findsOneWidget);
    expect(
      find.textContaining('Le montant rendu ne peut pas dépasser'),
      findsOneWidget,
    );
  });
}
