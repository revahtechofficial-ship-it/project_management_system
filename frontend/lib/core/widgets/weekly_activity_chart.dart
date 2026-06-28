import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Grouped bar chart of tasks created vs. completed across a window of days.
/// Pure presentation — the caller derives [days], [created] and [completed]
/// (parallel lists of equal length). Lives in `core/widgets` (used by the
/// dashboard and reports).
class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart({
    super.key,
    required this.days,
    required this.created,
    required this.completed,
  });

  final List<String> days;
  final List<double> created;
  final List<double> completed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double maxValue = <double>[...created, ...completed, 1]
        .reduce((double a, double b) => a > b ? a : b);
    final double maxY = (maxValue + 1).ceilToDouble();
    final double interval = maxY <= 5 ? 1 : (maxY / 4).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
            strokeWidth: 1,
            dashArray: <int>[4, 4],
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (BarChartGroupData group, int gi,
                    BarChartRodData rod, int ri) =>
                BarTooltipItem(
              rod.toY.toInt().toString(),
              TextStyle(
                  color: scheme.onInverseSurface,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(days[i],
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: i < created.length ? created[i] : 0,
                  color: scheme.primary,
                  width: 9,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: i < completed.length ? completed[i] : 0,
                  color: scheme.tertiary,
                  width: 9,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
