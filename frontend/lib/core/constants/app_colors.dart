import 'package:flutter/material.dart';

/// Brand and accent colors used across the app (AGENTS.md §1 `constants`).
///
/// These are accent/seed colors only — surfaces, text, and borders come from
/// the active [ColorScheme] so everything adapts to light and dark themes.
class AppColors {
  AppColors._();

  /// Primary brand color (indigo) — also the [ColorScheme] seed.
  static const Color brand = Color(0xFF4F46E5);
  static const Color violet = Color(0xFF7C3AED);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color teal = Color(0xFF14B8A6);
  static const Color green = Color(0xFF16A34A);
  static const Color amber = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFEA580C);
  static const Color rose = Color(0xFFE11D48);
  static const Color slate = Color(0xFF64748B);

  /// Deterministic palette for generated avatars.
  static const List<Color> avatarPalette = <Color>[
    brand, violet, sky, teal, green, amber, orange, rose,
  ];

  /// Premium brand gradient (indigo → violet) for primary accents and the
  /// active navigation pill.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  /// A two-stop gradient between [c] and a slightly darker shade, for icon
  /// badges and chips.
  static LinearGradient shade(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[c, Color.lerp(c, const Color(0xFF000000), 0.22)!],
      );
}
