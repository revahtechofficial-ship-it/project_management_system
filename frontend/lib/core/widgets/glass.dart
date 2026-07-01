import 'package:flutter/material.dart';

/// A clean, minimal app backdrop: a whisper-soft vertical gradient over a
/// neutral base. Kept intentionally flat so card surfaces read as the focus
/// (AGENTS.md §1 `core/widgets`).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // A barely-perceptible two-stop gradient — enough to give the page a soft
    // sense of depth without the busy "aurora" look.
    final List<Color> base = dark
        ? const <Color>[Color(0xFF0E1220), Color(0xFF0B0F1A)]
        : const <Color>[Color(0xFFFAFBFE), Color(0xFFF3F5FB)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: base,
        ),
      ),
      child: child,
    );
  }
}

/// A flat surface card: a solid fill, a hairline border and a single soft
/// shadow for subtle depth. The shared building block for cards and chrome
/// across the app (formerly a frosted-glass panel; kept the name and API so
/// callers need no changes).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.blur = 0,
    this.tint,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;

  /// Retained for backwards compatibility; the surface is now flat, so this no
  /// longer applies a backdrop blur.
  final double blur;

  /// Optional base fill color (defaults to the theme surface).
  final Color? tint;

  /// Optional override of the hairline border.
  final BoxBorder? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = tint ?? scheme.surface;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: radius,
        border: border ??
            Border.all(
              color: scheme.outlineVariant.withValues(alpha: dark ? 0.5 : 0.8),
              width: 1,
            ),
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}
