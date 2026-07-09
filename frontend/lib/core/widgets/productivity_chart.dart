import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A smooth area line chart of a single daily series (e.g. tasks completed per
/// day). Pure presentation — [labels] and [values] are parallel lists.
class ProductivityChart extends StatelessWidget {
  const ProductivityChart({
    super.key,
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double maxValue = <double>[
      ...values,
      1,
    ].reduce((double a, double b) => a > b ? a : b);
    final double maxY = (maxValue + 1).ceilToDouble();
    final double interval = maxY <= 5 ? 1 : (maxY / 4).ceilToDouble();
    final int step = labels.length <= 7 ? 1 : (labels.length / 6).ceil();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (labels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (List<LineBarSpot> spots) => spots
                .map(
                  (LineBarSpot s) => LineTooltipItem(
                    s.y.toInt().toString(),
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: interval,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                value.toInt().toString(),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= labels.length || i % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            isCurved: true,
            curveSmoothness: 0.3,
            color: scheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.25),
                  scheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            spots: <FlSpot>[
              for (int i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
          ),
        ],
      ),
    );
  }
}
