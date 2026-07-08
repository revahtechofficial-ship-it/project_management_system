import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/cycle_metrics.dart';
import 'providers/metrics_providers.dart';

/// Delivery metrics: cycle time, lead time and throughput from completed tasks,
/// with a lead-time control chart.
class MetricsPage extends ConsumerStatefulWidget {
  const MetricsPage({super.key});

  @override
  ConsumerState<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends ConsumerState<MetricsPage> {
  int _days = 90;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CycleMetrics> async = ref.watch(cycleMetricsProvider(_days));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Delivery metrics',
            subtitle: 'Cycle & lead time from completed tasks',
            actions: <Widget>[
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 30, label: Text('30d')),
                  ButtonSegment<int>(value: 90, label: Text('90d')),
                  ButtonSegment<int>(value: 180, label: Text('180d')),
                ],
                selected: <int>{_days},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> s) =>
                    setState(() => _days = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(cycleMetricsProvider(_days)),
              ),
              data: (CycleMetrics m) {
                if (m.completedCount == 0) {
                  return const EmptyState(
                    icon: Icons.timeline_outlined,
                    title: 'No completed tasks yet',
                    message: 'Cycle and lead time appear once tasks are '
                        'completed in the selected window.',
                  );
                }
                return _Body(metrics: m);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.metrics});
  final CycleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final CycleMetrics m = metrics;
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _StatCard(
              label: 'Avg lead time',
              value: '${m.avgLeadDays}',
              unit: 'days',
              hint: 'created → done',
            ),
            _StatCard(
              label: 'Median lead',
              value: '${m.medianLeadDays}',
              unit: 'days',
            ),
            _StatCard(
              label: '85th percentile',
              value: '${m.p85LeadDays}',
              unit: 'days',
              hint: 'most finish within',
            ),
            _StatCard(
              label: 'Avg cycle time',
              value: '${m.avgCycleDays}',
              unit: 'days',
              hint: 'start → done',
            ),
            _StatCard(
              label: 'Throughput',
              value: '${m.throughputPerWeek}',
              unit: '/ week',
              hint: '${m.completedCount} in ${m.days}d',
            ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'Lead time control chart',
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: SizedBox(height: 280, child: _ControlChart(metrics: m)),
          ),
        ),
        const SizedBox(height: 16),
        _SlowestCard(metrics: m),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.hint = '',
  });
  final String label;
  final String value;
  final String unit;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(value,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Text(unit,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
            if (hint.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(hint,
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlChart extends StatelessWidget {
  const _ControlChart({required this.metrics});
  final CycleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CyclePoint> pts = metrics.points;
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < pts.length; i++)
        FlSpot((i + 1).toDouble(), pts[i].leadDays),
    ];
    double maxY = metrics.p85LeadDays;
    for (final CyclePoint p in pts) {
      if (p.leadDays > maxY) {
        maxY = p.leadDays;
      }
    }
    maxY = (maxY <= 0 ? 1 : maxY) * 1.15;

    return LineChart(
      LineChartData(
        minX: 1,
        maxX: pts.length.toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double v) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                value.toStringAsFixed(0),
                style:
                    TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> spots) => spots
                .map((LineBarSpot s) => LineTooltipItem(
                      '${s.y} days',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: <HorizontalLine>[
            HorizontalLine(
              y: metrics.avgLeadDays,
              color: AppColors.green,
              strokeWidth: 1.5,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'avg ${metrics.avgLeadDays}d',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.green,
                    fontWeight: FontWeight.w700),
              ),
            ),
            HorizontalLine(
              y: metrics.p85LeadDays,
              color: AppColors.amber,
              strokeWidth: 1,
              dashArray: <int>[6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.bottomRight,
                labelResolver: (_) => '85th ${metrics.p85LeadDays}d',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.amber,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: scheme.primary,
            barWidth: 2,
            dotData: FlDotData(show: pts.length <= 60),
          ),
        ],
      ),
    );
  }
}

class _SlowestCard extends StatelessWidget {
  const _SlowestCard({required this.metrics});
  final CycleMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CyclePoint> sorted = <CyclePoint>[...metrics.points]
      ..sort((CyclePoint a, CyclePoint b) => b.leadDays.compareTo(a.leadDays));
    final List<CyclePoint> top = sorted.take(5).toList();
    return DashboardCard(
      title: 'Longest lead times',
      child: Column(
        children: <Widget>[
          for (final CyclePoint p in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(p.title.isEmpty ? 'Untitled' : p.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 12),
                  Text('${p.leadDays} d',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
