import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A full-bleed "aurora" backdrop: a soft base gradient with a few large,
/// heavily-blurred color blobs. Glass surfaces blur over it for depth
/// (AGENTS.md §1 `core/widgets`).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> base = dark
        ? const <Color>[Color(0xFF0B0F1C), Color(0xFF0E1326), Color(0xFF0B0F1C)]
        : const <Color>[Color(0xFFEFF1FE), Color(0xFFF5F3FD), Color(0xFFFDF2F8)];

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: base,
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -90,
          child: _Blob(
              color: AppColors.brand, size: 380, opacity: dark ? 0.30 : 0.22),
        ),
        Positioned(
          bottom: -140,
          right: -110,
          child: _Blob(
              color: AppColors.violet, size: 460, opacity: dark ? 0.26 : 0.20),
        ),
        Positioned(
          top: 180,
          right: 120,
          child: _Blob(
              color: AppColors.sky, size: 300, opacity: dark ? 0.18 : 0.14),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(
      {required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

/// A frosted-glass panel: a translucent gradient fill with a real backdrop
/// blur, a hairline highlight border and a soft drop shadow. The shared
/// building block for cards and chrome.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 18,
    this.tint,
    this.border,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final double blur;

  /// Optional base color of the glass (defaults to the surface color).
  final Color? tint;

  /// Optional override of the hairline border.
  final BoxBorder? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color baseTint = tint ?? scheme.surface;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.09),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  baseTint.withValues(alpha: dark ? 0.55 : 0.82),
                  baseTint.withValues(alpha: dark ? 0.34 : 0.66),
                ],
              ),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.10 : 0.65),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
