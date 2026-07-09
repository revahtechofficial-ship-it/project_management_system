import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/glass.dart';
import '../../core/widgets/revah_logo.dart';
import 'widgets/landing_buttons.dart';
import 'widgets/landing_hero.dart';
import 'widgets/landing_sections.dart';

/// The public marketing landing page — the front door for signed-out visitors
/// (AGENTS.md §1 feature page). It showcases only real capabilities.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AppBackground(
              child: SingleChildScrollView(
                child: Column(
                  children: const <Widget>[
                    SizedBox(height: 78),
                    LandingHero(),
                    FeatureGrid(),
                    ViewsShowcase(),
                    CtaBand(),
                    _Footer(),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _LandingNav()),
        ],
      ),
    );
  }
}

class _LandingNav extends StatelessWidget {
  const _LandingNav();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: dark ? 0.40 : 0.55),
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: <Widget>[
                        const _Brand(),
                        const Spacer(),
                        GhostButton(
                          label: 'Sign in',
                          onTap: () => context.go('/login'),
                        ),
                        const SizedBox(width: 10),
                        GradientButton(
                          label: 'Get started',
                          onTap: () => context.go('/signup'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) {
    return RevahLogo(height: height);
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: <Widget>[
              const _Brand(height: 30),
              const SizedBox(height: 10),
              Text(
                'Built in-house for the Revah Tech team.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Get started'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '© 2026 Revah Tech',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
