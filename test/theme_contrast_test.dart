import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/app/app.dart';
import 'package:game_credit_profit_manager/app/theme.dart';

void main() {
  test('يتبع التطبيق سمة الهاتف افتراضيًا', () {
    expect(appThemeMode, ThemeMode.system);
  });

  test('نص الأزرار الأساسية واضح فوق الخلفية الخضراء في الوضع الداكن', () {
    final theme = AppTheme.dark();
    final style = theme.filledButtonTheme.style!;
    final background = style.backgroundColor!.resolve(<WidgetState>{})!;
    final foreground = style.foregroundColor!.resolve(<WidgetState>{})!;

    expect(background, theme.colorScheme.primary);
    expect(foreground, theme.colorScheme.onPrimary);
    expect(_contrastRatio(background, foreground), greaterThanOrEqualTo(4.5));
  });

  test('يحافظ الوضع الفاتح على ألوانه الأساسية السابقة', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, const Color(0xFF21453B));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F1E9));
    expect(theme.cardTheme.color, const Color(0xFFFFFCF5));
  });

  test('ألوان الزر العائم في الوضع الداكن ذات تباين كاف', () {
    final theme = AppTheme.dark();
    final background = theme.floatingActionButtonTheme.backgroundColor!;
    final foreground = theme.floatingActionButtonTheme.foregroundColor!;

    expect(_contrastRatio(background, foreground), greaterThanOrEqualTo(4.5));
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
