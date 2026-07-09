import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/revah_logo.dart';
import 'auth_app_preview.dart';

/// A modern split auth layout: a clean form on the left and an animated product
/// showcase on the right (collapses to just the form on narrow screens). Used
/// by every auth page (AGENTS.md §1 feature widget).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 980;
            final Widget form = _FormSide(
              title: title,
              subtitle: subtitle,
              child: child,
            );
            if (!wide) {
              return form;
            }
            return Row(
              children: <Widget>[
                Expanded(flex: 5, child: form),
                const Expanded(flex: 6, child: _Showcase()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RevahLogo(height: 30),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double t, Widget? c) =>
                      Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 16),
                          child: c,
                        ),
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The animated product showcase: a refined gradient with soft glows, the app
/// preview (entrance + gentle float) and a few floating capability chips.
class _Showcase extends StatefulWidget {
  const _Showcase();

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> base = dark
        ? const <Color>[Color(0xFF0C1322), Color(0xFF0E1A2E)]
        : const <Color>[Color(0xFFEAF1FF), Color(0xFFEAFBFF)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: base,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -60,
            right: -30,
            child: _Glow(color: AppColors.sky, size: 320),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: _Glow(color: AppColors.teal, size: 340),
          ),
          Positioned(
            top: 220,
            left: 120,
            child: _Glow(color: AppColors.brand, size: 260),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double t, Widget? child) =>
                  Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 26),
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * t,
                        child: child,
                      ),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'YOUR WORKSPACE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Run projects with clarity.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _bob(
                      0.0,
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AuthAppPreview(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: 50,
            child: _bob(
              0.3,
              const _Chip(
                icon: Icons.account_tree_rounded,
                label: 'Critical path',
                color: AppColors.teal,
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 40,
            child: _bob(
              0.6,
              const _Chip(
                icon: Icons.flag_rounded,
                label: 'Milestones',
                color: AppColors.rose,
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            right: 30,
            child: _bob(
              0.85,
              const _Chip(
                icon: Icons.repeat_rounded,
                label: 'Recurring',
                color: AppColors.sky,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bob(double phase, Widget child) {
    return AnimatedBuilder(
      animation: _float,
      builder: (BuildContext context, Widget? c) {
        final double dy = math.sin((_float.value + phase) * math.pi * 2) * 6;
        return Transform.translate(offset: Offset(0, dy), child: c);
      },
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppColors.shade(color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: dark ? 0.22 : 0.28),
          ),
        ),
      ),
    );
  }
}
