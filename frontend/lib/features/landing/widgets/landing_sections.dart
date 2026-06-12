import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass.dart';
import 'landing_buttons.dart';

class _Feature {
  const _Feature(this.icon, this.color, this.title, this.desc);
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
}

// Only capabilities that actually exist in the app — no aspirational fluff.
const List<_Feature> _features = <_Feature>[
  _Feature(Icons.dashboard_customize_rounded, AppColors.brand,
      'Four task views', 'List, Board, Calendar and Gantt — same tasks, your choice.'),
  _Feature(Icons.account_tree_rounded, AppColors.violet,
      'Dependencies & critical path', 'Link tasks; successors auto-reschedule and the critical path is highlighted.'),
  _Feature(Icons.checklist_rounded, AppColors.teal, 'Subtasks & checklists',
      'Break work down with nested subtasks and quick checklists.'),
  _Feature(Icons.repeat_rounded, AppColors.sky, 'Recurring tasks',
      'Daily, weekly or monthly tasks that regenerate when completed.'),
  _Feature(Icons.flag_rounded, AppColors.rose, 'Milestones & baselines',
      'Mark key dates and snapshot the plan to track drift over time.'),
  _Feature(Icons.folder_rounded, AppColors.green, 'Projects & progress',
      'Group work into projects with live progress and members.'),
  _Feature(Icons.groups_rounded, AppColors.amber, 'Team & roles',
      'Owner / admin / member access, enforced on the server.'),
  _Feature(Icons.insights_rounded, AppColors.orange, 'Dashboard & reports',
      'KPIs, activity and productivity charts from your real data.'),
  _Feature(Icons.notifications_active_rounded, AppColors.brand, 'Notifications',
      'A workspace feed for completions, new projects and members.'),
];

/// Section heading used across the landing page.
class _Heading extends StatelessWidget {
  const _Heading({required this.eyebrow, required this.title, this.subtitle});
  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Text(eyebrow.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.brand)),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: scheme.onSurface)),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    color: scheme.onSurfaceVariant)),
          ),
        ],
      ],
    );
  }
}

/// Lifts its child on hover for a tactile, premium feel.
class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});
  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover ? const Offset(0, -0.03) : Offset.zero,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The "everything you need" feature grid.
class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: <Widget>[
              const _Heading(
                eyebrow: 'What\'s inside',
                title: 'Everything you need to plan and ship',
                subtitle:
                    'No bloat and no mock dashboards — just the tools the '
                    'Revah Tech team uses every day.',
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder:
                    (BuildContext context, BoxConstraints constraints) {
                  final double w = constraints.maxWidth;
                  final int cols = w >= 980 ? 3 : (w >= 640 ? 2 : 1);
                  const double gap = 18;
                  final double cardW =
                      (w - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final _Feature f in _features)
                        SizedBox(
                          width: cardW,
                          child: _HoverLift(child: _FeatureTile(feature: f)),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GlassSurface(
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.shade(feature.color),
                borderRadius: BorderRadius.circular(13),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: feature.color.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(feature.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(feature.title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(feature.desc,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Highlights the four task views.
class ViewsShowcase extends StatelessWidget {
  const ViewsShowcase({super.key});

  static const List<_Feature> _views = <_Feature>[
    _Feature(Icons.view_list_rounded, AppColors.brand, 'List',
        'A fast, sortable list with status, assignee and due dates.'),
    _Feature(Icons.view_kanban_rounded, AppColors.violet, 'Board',
        'Drag cards between workflow columns to update status.'),
    _Feature(Icons.calendar_month_rounded, AppColors.sky, 'Calendar',
        'See tasks on the month they\'re due, at a glance.'),
    _Feature(Icons.view_timeline_rounded, AppColors.teal, 'Timeline',
        'A Gantt with dependency arrows, baselines and milestones.'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: <Widget>[
              const _Heading(
                eyebrow: 'One workspace',
                title: 'See your work your way',
                subtitle:
                    'Switch between four views on the very same tasks — '
                    'instantly, with no setup.',
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder:
                    (BuildContext context, BoxConstraints constraints) {
                  final double w = constraints.maxWidth;
                  final int cols = w >= 900 ? 4 : (w >= 560 ? 2 : 1);
                  const double gap = 16;
                  final double cardW = (w - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: <Widget>[
                      for (final _Feature v in _views)
                        SizedBox(
                          width: cardW,
                          child: _HoverLift(
                            child: GlassSurface(
                              borderRadius: 18,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(v.icon, color: v.color, size: 30),
                                    const SizedBox(height: 14),
                                    Text(v.title,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 7),
                                    Text(v.desc,
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.5,
                                            color:
                                                scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A closing call-to-action band.
class CtaBand extends StatelessWidget {
  const CtaBand({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 70),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: GlassSurface(
            borderRadius: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 48),
              child: Column(
                children: <Widget>[
                  Text('Ready to get organized?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: scheme.onSurface)),
                  const SizedBox(height: 10),
                  Text('Create your account and start planning in seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
