import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF21453B);
  static const _accent = Color(0xFFE0A02B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final scheme = dark
        ? generated.copyWith(
            primary: const Color(0xFF2F806A),
            onPrimary: const Color(0xFFFFFFFF),
            primaryContainer: const Color(0xFF215444),
            onPrimaryContainer: const Color(0xFFE7FFF6),
            secondary: _accent,
            onSecondary: const Color(0xFF281A00),
            secondaryContainer: const Color(0xFF5D4300),
            onSecondaryContainer: const Color(0xFFFFE2A3),
            tertiary: const Color(0xFF82B7E8),
            onTertiary: const Color(0xFF002E4E),
            error: const Color(0xFFFFB4AB),
            onError: const Color(0xFF690005),
            surface: const Color(0xFF101512),
            onSurface: const Color(0xFFF0F5F1),
            surfaceContainerHighest: const Color(0xFF26312B),
            onSurfaceVariant: const Color(0xFFD4DDD7),
            outline: const Color(0xFF8B9890),
            outlineVariant: const Color(0xFF445148),
          )
        : generated.copyWith(
            primary: _seed,
            secondary: _accent,
            tertiary: const Color(0xFF315C80),
            error: const Color(0xFFB3261E),
          );

    final filledButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: dark ? scheme.primary : null,
      foregroundColor: dark ? scheme.onPrimary : null,
      disabledBackgroundColor:
          dark ? scheme.surfaceContainerHighest : null,
      disabledForegroundColor:
          dark ? scheme.onSurfaceVariant.withValues(alpha: 0.62) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF101512) : const Color(0xFFF4F1E9),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF18201C) : const Color(0xFFFFFCF5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 21,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1D2722) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: dark
          ? ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
                disabledForegroundColor:
                    scheme.onSurfaceVariant.withValues(alpha: 0.62),
              ),
            )
          : const ElevatedButtonThemeData(),
      floatingActionButtonTheme: dark
          ? FloatingActionButtonThemeData(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            )
          : const FloatingActionButtonThemeData(),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          backgroundColor: dark
              ? WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? scheme.primary
                      : Colors.transparent;
                })
              : null,
          foregroundColor: dark
              ? WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? scheme.onPrimary
                      : scheme.onSurface;
                })
              : null,
        ),
      ),
      chipTheme: dark
          ? ChipThemeData(
              backgroundColor: scheme.surfaceContainerHighest,
              selectedColor: scheme.primary,
              labelStyle: TextStyle(color: scheme.onSurface),
              secondaryLabelStyle: TextStyle(color: scheme.onPrimary),
              iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
              secondarySelectedColor: scheme.primary,
              side: BorderSide(color: scheme.outlineVariant),
            )
          : const ChipThemeData(),
      switchTheme: dark
          ? SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.surfaceContainerHighest;
              }),
              trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
            )
          : const SwitchThemeData(),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
