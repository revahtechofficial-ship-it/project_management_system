import 'package:flutter/material.dart';

/// A single colored entry in a [ChartLegend].
class LegendItem {
  const LegendItem(this.color, this.label);
  final Color color;
  final String label;
}

/// A horizontal, wrapping legend for charts (AGENTS.md §1 `core/widgets`).
class ChartLegend extends StatelessWidget {
  const ChartLegend({
    super.key,
    required this.items,
    this.alignment = WrapAlignment.center,
  });

  final List<LegendItem> items;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      alignment: alignment,
      children: <Widget>[
        for (final LegendItem item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: item.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(item.label,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
      ],
    );
  }
}
