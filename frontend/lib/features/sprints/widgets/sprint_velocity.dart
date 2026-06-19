import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/enums/sprint_status.dart';
import '../../../data/models/sprint.dart';

/// A velocity chart: committed vs completed story points per sprint, with the
/// average velocity across completed sprints (AGENTS.md §1 feature view).
class SprintVelocity extends StatelessWidget {
  const SprintVelocity({super.key, required this.sprints});

  final List<Sprint> sprints;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Oldest → newest so the trend reads left to right.
    final List<Sprint> ordered = <Sprint>[...sprints]
      ..sort((Sprint a, Sprint b) => a.id.compareTo(b.id));
    if (ordered.every((Sprint s) => s.totalPoints == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Add story points to your sprints to track velocity.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final List<Sprint> completed = ordered
        .where((Sprint s) => s.status == SprintStatus.completed)
        .toList(growable: false);
    final int avg = completed.isEmpty
        ? 0
        : (completed.fold<int>(0, (int s, Sprint x) => s + x.donePoints) /
                  completed.length)
              .round();
    final int maxPoints = ordered.fold<int>(
      1,
      (int m, Sprint s) => s.totalPoints > m ? s.totalPoints : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _Swatch(color: AppColors.brand, label: 'Completed'),
            const SizedBox(width: 16),
            _Swatch(color: scheme.surfaceContainerHighest, label: 'Committed'),
            const Spacer(),
            if (completed.isNotEmpty)
              Text(
                'Avg velocity: $avg pts',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final Sprint s in ordered)
                  _VelocityBar(sprint: s, maxPoints: maxPoints),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VelocityBar extends StatelessWidget {
  const _VelocityBar({required this.sprint, required this.maxPoints});

  final Sprint sprint;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    const double barH = 120;
    final double committedH = barH * (sprint.totalPoints / maxPoints);
    final double doneH = barH * (sprint.donePoints / maxPoints);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            '${sprint.donePoints}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Container(
                width: 36,
                height: committedH < 4 ? 4 : committedH,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: doneH < 2 ? 2 : doneH,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              sprint.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
