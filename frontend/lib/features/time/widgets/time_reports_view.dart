import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/dashboard_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../data/models/time_entry.dart';
import '../providers/time_providers.dart';

enum _Range { week, month, days30 }

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Time reporting + analytics: totals, billable split, and per-member and
/// per-task breakdowns over a selectable range. Admins see the whole team;
/// members see their own (AGENTS.md §1 feature view).
class TimeReportsView extends ConsumerStatefulWidget {
  const TimeReportsView({super.key});

  @override
  ConsumerState<TimeReportsView> createState() => _TimeReportsViewState();
}

class _TimeReportsViewState extends ConsumerState<TimeReportsView> {
  _Range _range = _Range.week;

  (String from, String to) _bounds() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime to = today.add(const Duration(days: 1));
    final DateTime from = switch (_range) {
      _Range.week => today.subtract(Duration(days: today.weekday - 1)),
      _Range.month => DateTime(now.year, now.month),
      _Range.days30 => today.subtract(const Duration(days: 30)),
    };
    return (_ymd(from), _ymd(to));
  }

  @override
  Widget build(BuildContext context) {
    final (String from, String to) = _bounds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SegmentedButton<_Range>(
          segments: const <ButtonSegment<_Range>>[
            ButtonSegment<_Range>(value: _Range.week, label: Text('This week')),
            ButtonSegment<_Range>(
              value: _Range.month,
              label: Text('This month'),
            ),
            ButtonSegment<_Range>(value: _Range.days30, label: Text('30 days')),
          ],
          selected: <_Range>{_range},
          showSelectedIcon: false,
          onSelectionChanged: (Set<_Range> s) =>
              setState(() => _range = s.first),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<TimeEntry>>(
            future: ref
                .read(timeEntriesRepositoryProvider)
                .teamList(from: from, to: to),
            builder:
                (BuildContext context, AsyncSnapshot<List<TimeEntry>> snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const LoadingView();
                  }
                  if (snap.hasError) {
                    return ErrorView(
                      error: snap.error,
                      onRetry: () => setState(() {}),
                    );
                  }
                  return _Report(entries: snap.data ?? const <TimeEntry>[]);
                },
          ),
        ),
      ],
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.entries});

  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No time logged in this range.'));
    }
    int total = 0, billable = 0;
    final Map<String, int> byMember = <String, int>{};
    final Map<String, int> byTask = <String, int>{};
    for (final TimeEntry e in entries) {
      total += e.minutes;
      if (e.billable) {
        billable += e.minutes;
      }
      final String who = e.userName.isEmpty ? 'You' : e.userName;
      byMember[who] = (byMember[who] ?? 0) + e.minutes;
      byTask[e.subject] = (byTask[e.subject] ?? 0) + e.minutes;
    }
    final int pct = total == 0 ? 0 : (billable * 100 / total).round();

    return ListView(
      children: <Widget>[
        StatCardGrid(
          cards: <Widget>[
            StatCard(
              icon: Icons.schedule,
              color: AppColors.brand,
              label: 'Total time',
              value: TimeEntry.formatMinutes(total),
              footer: '${entries.length} entries',
            ),
            StatCard(
              icon: Icons.attach_money,
              color: AppColors.green,
              label: 'Billable',
              value: TimeEntry.formatMinutes(billable),
              footer: '$pct% of total',
              progress: total == 0 ? 0 : billable / total,
            ),
            StatCard(
              icon: Icons.groups_2_outlined,
              color: AppColors.violet,
              label: 'People',
              value: '${byMember.length}',
              footer: 'logged time',
            ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'By person',
          child: _Breakdown(data: byMember, color: AppColors.brand),
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'By task',
          child: _Breakdown(data: byTask, color: AppColors.teal, limit: 8),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data, required this.color, this.limit});

  final Map<String, int> data;
  final Color color;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<MapEntry<String, int>> rows = data.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    final List<MapEntry<String, int>> shown = limit == null
        ? rows
        : rows.take(limit!).toList();
    final int max = shown.isEmpty ? 0 : shown.first.value;
    return Column(
      children: <Widget>[
        for (final MapEntry<String, int> e in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      TimeEntry.formatMinutes(e.value),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
