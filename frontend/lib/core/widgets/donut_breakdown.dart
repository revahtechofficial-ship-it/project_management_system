import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/spacing.dart';

/// One slice of a [DonutBreakdown].
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
}

/// A donut chart of a categorical breakdown (e.g. tasks by priority or status)
/// with a value/percentage legend beside it.
class DonutBreakdown extends StatelessWidget {
  const DonutBreakdown({
    super.key,
    required this.segments,
    this.centerLabel,
    this.size = 168,
  });

  final List<DonutSegment> segments;
  final String? centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = segments.fold<int>(
      0,
      (int s, DonutSegment e) => s + e.value,
    );

    final Widget donut = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PieChart(
            PieChartData(
              sectionsSpace: total == 0 ? 0 : 2,
              centerSpaceRadius: size * 0.30,
              startDegreeOffset: -90,
              sections: total == 0
                  ? <PieChartSectionData>[
                      PieChartSectionData(
                        value: 1,
                        color: scheme.surfaceContainerHighest,
                        radius: size * 0.16,
                        showTitle: false,
                      ),
                    ]
                  : <PieChartSectionData>[
                      for (final DonutSegment s in segments)
                        if (s.value > 0)
                          PieChartSectionData(
                            value: s.value.toDouble(),
                            color: s.color,
                            radius: size * 0.16,
                            showTitle: false,
                          ),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$total',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: tabularFigures,
                ),
              ),
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final Widget legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final DonutSegment s in segments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${s.value}'
                  '${total == 0 ? '' : '  ·  ${((s.value / total) * 100).round()}%'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth < 340) {
          return Column(
            children: <Widget>[donut, const SizedBox(height: 12), legend],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            donut,
            const SizedBox(width: 20),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}
