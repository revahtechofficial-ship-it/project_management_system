import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A donut chart of completed vs. pending tasks with the completion rate
/// rendered in the empty centre. Pure presentation (used by dashboard and
/// reports).
class TaskStatusChart extends StatelessWidget {
  const TaskStatusChart({
    super.key,
    required this.completed,
    required this.pending,
  });

  final int completed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = completed + pending;
    final int percent = total == 0 ? 0 : ((completed / total) * 100).round();

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        PieChart(
          PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 58,
            startDegreeOffset: -90,
            sections: <PieChartSectionData>[
              PieChartSectionData(
                value: total == 0 ? 1 : completed.toDouble(),
                color: total == 0
                    ? scheme.surfaceContainerHighest
                    : scheme.tertiary,
                radius: 22,
                showTitle: false,
              ),
              PieChartSectionData(
                value: total == 0 ? 0 : pending.toDouble(),
                color: scheme.primary,
                radius: 22,
                showTitle: false,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            Text(
              'completed',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
