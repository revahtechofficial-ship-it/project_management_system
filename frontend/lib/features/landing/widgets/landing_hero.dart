import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass.dart';
import 'landing_buttons.dart';

/// The landing hero: a staggered entrance animation over the aurora backdrop,
/// with a cluster of gently floating glass cards that name real capabilities
/// (no mock data).
class LandingHero extends StatefulWidget {
  const LandingHero({super.key});

  @override
  State<LandingHero> createState() => _LandingHeroState();
}

class _LandingHeroState extends State<LandingHero>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _in.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _fade(int i) {
    final double start = (0.09 * i).clamp(0.0, 0.55);
    return CurvedAnimation(
      parent: _in,
      curve: Interval(
        start,
        (start + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _reveal(int i, Widget child) {
    final Animation<double> a = _fade(i);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _reveal(0, const _Eyebrow()),
        const SizedBox(height: 22),
        _reveal(1, const _Headline()),
        const SizedBox(height: 20),
        _reveal(
          2,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Revah Management System brings your tasks, projects and '
              'timelines together — List, Board, Calendar and Gantt views, '
              'dependencies, milestones and roles — in one fast, modern '
              'workspace built for the Revah Tech team.',
              style: TextStyle(
                fontSize: 17,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        _reveal(
          3,
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: <Widget>[
              GradientButton(
                label: 'Get started',
                large: true,
                icon: Icons.arrow_forward_rounded,
                onTap: () => context.go('/signup'),
              ),
              GhostButton(
                label: 'Sign in',
                large: true,
                onTap: () => context.go('/login'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _reveal(
          4,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'For the Revah Tech team · email verification built in',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 920) {
                return text;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(flex: 6, child: text),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: _reveal(2, _FloatingCards(float: _float)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 14, color: AppColors.brand),
          const SizedBox(width: 7),
          Text(
            'Project & task management, in-house',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const TextStyle base = TextStyle(
      fontSize: 52,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Run every project',
          style: base.copyWith(color: scheme.onSurface),
        ),
        ShaderMask(
          shaderCallback: (Rect bounds) => AppColors.brandGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'in one calm place.',
            style: TextStyle(
              fontSize: 52,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingCards extends StatelessWidget {
  const _FloatingCards({required this.float});
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        children: <Widget>[
          _FloatCard(
            float: float,
            top: 10,
            left: 40,
            phase: 0.0,
            icon: Icons.view_kanban_rounded,
            label: 'Board',
            color: AppColors.brand,
          ),
          _FloatCard(
            float: float,
            top: 70,
            right: 0,
            phase: 0.35,
            icon: Icons.view_timeline_rounded,
            label: 'Gantt timeline',
            color: AppColors.violet,
          ),
          _FloatCard(
            float: float,
            top: 180,
            left: 0,
            phase: 0.6,
            icon: Icons.account_tree_rounded,
            label: 'Dependencies',
            color: AppColors.teal,
          ),
          _FloatCard(
            float: float,
            top: 240,
            right: 60,
            phase: 0.15,
            icon: Icons.flag_rounded,
            label: 'Milestones',
            color: AppColors.rose,
          ),
          _FloatCard(
            float: float,
            top: 150,
            left: 130,
            phase: 0.8,
            icon: Icons.calendar_month_rounded,
            label: 'Calendar',
            color: AppColors.sky,
          ),
        ],
      ),
    );
  }
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({
    required this.float,
    required this.icon,
    required this.label,
    required this.color,
    required this.phase,
    this.top,
    this.left,
    this.right,
  });

  final Animation<double> float;
  final IconData icon;
  final String label;
  final Color color;
  final double phase;
  final double? top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: float,
        builder: (BuildContext context, Widget? child) {
          final double dy = math.sin((float.value + phase) * math.pi * 2) * 7;
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: GlassSurface(
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: AppColors.shade(color),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
