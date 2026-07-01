import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// One step of the first-run tour.
class _TourStep {
  const _TourStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const List<_TourStep> _steps = <_TourStep>[
  _TourStep(
    icon: Icons.dashboard_customize_rounded,
    color: AppColors.brand,
    title: 'Welcome to Revah',
    body: 'Your workspace for projects, tasks, docs and team chat — all in '
        'one place. Here are a few things to get you started.',
  ),
  _TourStep(
    icon: Icons.search_rounded,
    color: AppColors.sky,
    title: 'Find anything fast',
    body: 'Press Ctrl/⌘ + K anywhere to search tasks and projects, jump to a '
        'page, or run a quick action.',
  ),
  _TourStep(
    icon: Icons.add_circle_outline_rounded,
    color: AppColors.green,
    title: 'Create in one click',
    body: 'Use Quick add on the dashboard to spin up a task, project, page or '
        'reminder without leaving home.',
  ),
  _TourStep(
    icon: Icons.insights_rounded,
    color: AppColors.violet,
    title: 'Stay on top of work',
    body: 'The dashboard shows your KPIs, trends and what needs attention. '
        'Pin your favourite pages to the sidebar with a right-click.',
  ),
];

/// Shows the first-run tour. Returns when the user finishes or skips.
Future<void> showOnboardingTour(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _OnboardingTourDialog(),
  );
}

class _OnboardingTourDialog extends StatefulWidget {
  const _OnboardingTourDialog();

  @override
  State<_OnboardingTourDialog> createState() => _OnboardingTourDialogState();
}

class _OnboardingTourDialogState extends State<_OnboardingTourDialog> {
  int _index = 0;

  void _next() {
    if (_index >= _steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _TourStep step = _steps[_index];
    final bool last = _index == _steps.length - 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(step.icon, color: step.color, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                step.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                step.body,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  for (int i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? step.color
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Skip'),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
