import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's light and dark [ThemeData] from a single seed, tuned for a
/// modern glassmorphism look: translucent inputs, soft rounded components and
/// an aurora base color (AGENTS.md §1 `constants`; theming skill).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    // Darken (light) / lighten (dark) the muted text + borders that come out of
    // the seed so secondary copy and card edges read clearly — the defaults are
    // too low-contrast on the translucent glass surfaces.
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      onSurfaceVariant: dark
          ? const Color(0xFFB4BCCC)
          : const Color(0xFF4B5563),
      outlineVariant: dark
          ? const Color(0xFF333B4F)
          : const Color(0xFFC4CAD8),
    );
    final Color base =
        dark ? const Color(0xFF0B0F1C) : const Color(0xFFF1F3FC);

    OutlineInputBorder borderOf(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest
            .withValues(alpha: dark ? 0.35 : 0.55),
        border: borderOf(scheme.outlineVariant.withValues(alpha: 0.5)),
        enabledBorder:
            borderOf(scheme.outlineVariant.withValues(alpha: 0.5)),
        focusedBorder: borderOf(scheme.primary, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
