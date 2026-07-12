import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/app/theme.dart';
import 'package:game_credit_profit_manager/shared/providers/theme_mode_provider.dart';

void main() {
  test('سمة الهاتف هي الخيار الافتراضي', () {
    expect(AppThemeModePreference.system.themeMode, ThemeMode.system);
    expect(AppThemeModePreference.system.isDark(Brightness.dark), isTrue);
    expect(AppThemeModePreference.system.isDark(Brightness.light), isFalse);
  });

  test('الاختيار اليدوي يتجاوز سمة الهاتف', () {
    expect(AppThemeModePreference.dark.themeMode, ThemeMode.dark);
    expect(AppThemeModePreference.light.themeMode, ThemeMode.light);
    expect(AppThemeModePreference.dark.isDark(Brightness.light), isTrue);
    expect(AppThemeModePreference.light.isDark(Brightness.dark), isFalse);
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
