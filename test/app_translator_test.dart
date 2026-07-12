import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/localization/app_translator.dart';

void main() {
  test('يحافظ على النص العربي عند اختيار العربية', () {
    expect(
      AppTranslator.translateForLanguage('مخزون الرصيد', 'ar'),
      'مخزون الرصيد',
    );
  });

  test('يترجم العناوين الأساسية إلى الفرنسية', () {
    expect(
      AppTranslator.translateForLanguage('مخزون الرصيد', 'fr'),
      'Stock de crédit',
    );
    expect(
      AppTranslator.translateForLanguage('عملية جديدة', 'fr'),
      'Nouvelle opération',
    );
    expect(
      AppTranslator.translateForLanguage('الإعدادات', 'fr'),
      'Paramètres',
    );
  });

  test('يترجم القيم الديناميكية مع إبقاء الأرقام', () {
    expect(
      AppTranslator.translateForLanguage('240 رصيد = 350 دج', 'fr'),
      '240 crédits = 350 DA',
    );
    expect(
      AppTranslator.translateForLanguage('5 عملية', 'fr'),
      '5 opérations',
    );
    expect(
      AppTranslator.translateForLanguage('من 01/07/2026 إلى 12/07/2026', 'fr'),
      'Du 01/07/2026 au 12/07/2026',
    );
  });
}
