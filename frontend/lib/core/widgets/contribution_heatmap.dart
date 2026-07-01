import 'package:flutter/material.dart';

/// A GitHub-style contribution calendar: [weeks] columns of seven day cells,
/// shaded by each day's count. [counts] is keyed by day (any time is floored
/// to midnight). [anchor] is the most recent day shown (defaults to today —
/// pass it in so the widget stays deterministic/testable).
class ContributionHeatmap extends StatelessWidget {
  const ContributionHeatmap({
    super.key,
    required this.counts,
    required this.anchor,
    this.color,
    this.weeks = 16,
    this.cell = 14,
    this.gap = 3,
  });

  final Map<DateTime, int> counts;
  final DateTime anchor;
  final Color? color;
  final int weeks;
  final double cell;
  final double gap;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = color ?? scheme.primary;
    final Color empty = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final DateTime today = _day(anchor);
    // Monday of the current week, then wind back to the first shown week.
    final DateTime thisMonday =
        today.subtract(Duration(days: today.weekday - 1));
    final DateTime firstMonday =
        thisMonday.subtract(Duration(days: (weeks - 1) * 7));

    int maxCount = 1;
    counts.forEach((DateTime _, int v) {
      if (v > maxCount) maxCount = v;
    });

    Color shade(int count) {
      if (count <= 0) {
        return empty;
      }
      // Four intensity buckets.
      final double t = (count / maxCount).clamp(0.0, 1.0);
      final double alpha = 0.25 + 0.75 * t;
      return accent.withValues(alpha: alpha);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int w = 0; w < weeks; w++)
                Padding(
                  padding: EdgeInsets.only(right: gap),
                  child: Column(
                    children: <Widget>[
                      for (int d = 0; d < 7; d++)
                        Builder(
                          builder: (BuildContext context) {
                            final DateTime day = firstMonday
                                .add(Duration(days: w * 7 + d));
                            final bool future = day.isAfter(today);
                            final int count = counts[day] ?? 0;
                            return Padding(
                              padding: EdgeInsets.only(bottom: gap),
                              child: Tooltip(
                                message: future
                                    ? ''
                                    : '${day.year}-'
                                        '${day.month.toString().padLeft(2, '0')}-'
                                        '${day.day.toString().padLeft(2, '0')}'
                                        '  ·  $count',
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    color: future
                                        ? Colors.transparent
                                        : shade(count),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Less',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              for (final double a in <double>[0.25, 0.5, 0.75, 1.0])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: a),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 3),
              Text(
                'More',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
