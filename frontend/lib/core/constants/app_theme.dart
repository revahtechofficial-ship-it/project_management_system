import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's light and dark [ThemeData] from a single seed, tuned for a
/// clean, modern SaaS look: flat solid surfaces with subtle depth, soft
/// neutral backgrounds, generously rounded corners and hairline borders
/// (AGENTS.md §1 `constants`; theming skill).
class AppTheme {
  AppTheme._();

  static ThemeData light({
    Color? seed,
    bool compact = false,
    bool reduceMotion = false,
  }) =>
      _build(Brightness.light, seed ?? AppColors.brand, compact, reduceMotion);
  static ThemeData dark({
    Color? seed,
    bool compact = false,
    bool reduceMotion = false,
  }) =>
      _build(Brightness.dark, seed ?? AppColors.brand, compact, reduceMotion);

  static ThemeData _build(
    Brightness brightness,
    Color seed,
    bool compact,
    bool reduceMotion,
  ) {
    final bool dark = brightness == Brightness.dark;
    // Tune the muted text + hairline borders from the seed: readable secondary
    // copy, and very light card edges so surfaces read as flat panels with
    // just a whisper of separation.
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      surface: dark ? const Color(0xFF161B27) : Colors.white,
      onSurfaceVariant: dark
          ? const Color(0xFFAEB6C6)
          : const Color(0xFF5B6472),
      outlineVariant: dark
          ? const Color(0xFF2A3140)
          : const Color(0xFFE4E9F1),
    );
    final Color base =
        dark ? const Color(0xFF0B0F1A) : const Color(0xFFF3F5FB);
    final Color inputFill =
        dark ? const Color(0xFF1C2230) : const Color(0xFFF1F4F9);

    OutlineInputBorder borderOf(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      pageTransitionsTheme: reduceMotion
          ? const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: _NoTransitionsBuilder(),
                TargetPlatform.iOS: _NoTransitionsBuilder(),
                TargetPlatform.linux: _NoTransitionsBuilder(),
                TargetPlatform.macOS: _NoTransitionsBuilder(),
                TargetPlatform.windows: _NoTransitionsBuilder(),
              },
            )
          : null,
      // A slightly stronger hover so list rows and ink wells visibly respond
      // to the mouse across the app (the M3 default is barely perceptible).
      hoverColor: scheme.onSurface.withValues(alpha: dark ? 0.06 : 0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: borderOf(scheme.outlineVariant),
        enabledBorder: borderOf(scheme.outlineVariant),
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

/// A page transition that renders the destination instantly, used when the
/// "reduce motion" preference is enabled.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
