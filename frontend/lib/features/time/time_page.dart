import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/task.dart';
import '../../data/models/time_entry.dart';
import '../tasks/providers/tasks_providers.dart';
import 'providers/time_providers.dart';
import 'widgets/time_entry_dialog.dart';
import 'widgets/time_reports_view.dart';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

enum _TimeView { timesheet, estimates, reports }

/// The time tracker: a built-in timer, a manual time log, the timesheet, and a
/// reporting view with team/billable analytics (AGENTS.md §1 feature page).
class TimePage extends ConsumerStatefulWidget {
  const TimePage({super.key});

  @override
  ConsumerState<TimePage> createState() => _TimePageState();
}

class _TimePageState extends ConsumerState<TimePage> {
  _TimeView _view = _TimeView.timesheet;

  Future<void> _logTime() async {
    final bool? saved = await showTimeEntryDialog(context);
    if ((saved ?? false)) {
      ref.invalidate(myTimeEntriesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Time',
            subtitle: 'Track time with the timer or log it manually',
            actions: <Widget>[
              SegmentedButton<_TimeView>(
                segments: const <ButtonSegment<_TimeView>>[
                  ButtonSegment<_TimeView>(
                    value: _TimeView.timesheet,
                    icon: Icon(Icons.list_alt_outlined, size: 18),
                    label: Text('Timesheet'),
                  ),
                  ButtonSegment<_TimeView>(
                    value: _TimeView.estimates,
                    icon: Icon(Icons.balance_outlined, size: 18),
                    label: Text('Estimates'),
                  ),
                  ButtonSegment<_TimeView>(
                    value: _TimeView.reports,
                    icon: Icon(Icons.bar_chart_outlined, size: 18),
                    label: Text('Reports'),
                  ),
                ],
                selected: <_TimeView>{_view},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_TimeView> s) =>
                    setState(() => _view = s.first),
              ),
              if (_view == _TimeView.timesheet)
                FilledButton.icon(
                  onPressed: _logTime,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log time'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_view) {
              _TimeView.timesheet => const _TimesheetBody(),
              _TimeView.estimates => const _EstimatesView(),
              _TimeView.reports => const TimeReportsView(),
            },
          ),
        ],
      ),
    );
  }
}

/// The timer + timesheet (the default Time view).
class _TimesheetBody extends ConsumerWidget {
  const _TimesheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TimeEntry?> active = ref.watch(activeTimerProvider);
    final AsyncValue<List<TimeEntry>> entries = ref.watch(
      myTimeEntriesProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        active.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _StartBar(),
          data: (TimeEntry? t) =>
              t == null ? const _StartBar() : _RunningBar(entry: t),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: entries.when(
            loading: () => const LoadingView(),
            error: (Object e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(myTimeEntriesProvider),
            ),
            data: (List<TimeEntry> items) {
              final List<TimeEntry> done = items
                  .where((TimeEntry e) => !e.running)
                  .toList(growable: false);
              if (done.isEmpty) {
                return const EmptyState(
                  icon: Icons.timer_outlined,
                  message: 'No time logged yet. Start the timer or log time.',
                );
              }
              return _Timesheet(entries: done);
            },
          ),
        ),
      ],
    );
  }
}

/// The idle state: pick a task, describe the work, and start the timer.
class _StartBar extends ConsumerStatefulWidget {
  const _StartBar();

  @override
  ConsumerState<_StartBar> createState() => _StartBarState();
}

class _StartBarState extends ConsumerState<_StartBar> {
  final TextEditingController _desc = TextEditingController();
  int? _taskId;
  bool _billable = false;
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(timeEntriesRepositoryProvider)
          .start(
            taskId: _taskId,
            description: _desc.text.trim(),
            billable: _billable,
          );
      ref.invalidate(activeTimerProvider);
      ref.invalidate(myTimeEntriesProvider);
    } catch (e) {
      if (mounted) {
        context.showError('Could not start: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    return DashboardCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 240,
            child: _TaskDropdown(
              tasks: tasks,
              value: _taskId,
              onChanged: (int? v) => setState(() => _taskId = v),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _desc,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'What are you working on?',
              ),
            ),
          ),
          FilterChip(
            label: const Text('Billable'),
            selected: _billable,
            onSelected: (bool v) => setState(() => _billable = v),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

/// The active timer with a live ticking clock and a Stop button.
class _RunningBar extends ConsumerStatefulWidget {
  const _RunningBar({required this.entry});

  final TimeEntry entry;

  @override
  ConsumerState<_RunningBar> createState() => _RunningBarState();
}

class _RunningBarState extends ConsumerState<_RunningBar> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await ref.read(timeEntriesRepositoryProvider).stop(widget.entry.id);
      ref.invalidate(activeTimerProvider);
      ref.invalidate(myTimeEntriesProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not stop: $e');
      }
    }
  }

  String _elapsed() {
    final Duration d = DateTime.now().difference(widget.entry.startedAt);
    final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          const Icon(Icons.timer, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.entry.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.entry.billable)
                  Text(
                    'Billable',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _elapsed(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: _busy ? null : _stop,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

/// Estimate vs actual: compares each task's estimate against the time logged
/// against it, surfacing where work is running over or under.
class _EstimatesView extends ConsumerWidget {
  const _EstimatesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final AsyncValue<List<TimeEntry>> entriesAsync =
        ref.watch(myTimeEntriesProvider);

    return entriesAsync.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(myTimeEntriesProvider),
      ),
      data: (List<TimeEntry> entries) {
        final Map<int, int> actualByTask = <int, int>{};
        for (final TimeEntry e in entries) {
          if (e.taskId != null) {
            actualByTask[e.taskId!] =
                (actualByTask[e.taskId!] ?? 0) + e.minutes;
          }
        }
        final List<({Task task, int estimate, int actual})> rows =
            <({Task task, int estimate, int actual})>[
          for (final Task t in tasks)
            if (t.estimateMinutes > 0 || (actualByTask[t.id] ?? 0) > 0)
              (
                task: t,
                estimate: t.estimateMinutes,
                actual: actualByTask[t.id] ?? 0,
              ),
        ]..sort((({Task task, int estimate, int actual}) a,
                ({Task task, int estimate, int actual}) b) =>
            (b.actual - b.estimate).compareTo(a.actual - a.estimate));

        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.balance_outlined,
            title: 'Nothing to compare yet',
            message: 'Add an estimate to a task and log time against it to see '
                'estimate vs actual here.',
          );
        }

        final int totalEst =
            rows.fold<int>(0, (int s, ({Task task, int estimate, int actual}) r) => s + r.estimate);
        final int totalAct =
            rows.fold<int>(0, (int s, ({Task task, int estimate, int actual}) r) => s + r.actual);

        return ListView(
          children: <Widget>[
            _EstimateSummary(estimate: totalEst, actual: totalAct),
            const SizedBox(height: 16),
            for (final ({Task task, int estimate, int actual}) r in rows)
              _EstimateRow(task: r.task, estimate: r.estimate, actual: r.actual),
          ],
        );
      },
    );
  }
}

class _EstimateSummary extends StatelessWidget {
  const _EstimateSummary({required this.estimate, required this.actual});
  final int estimate;
  final int actual;

  @override
  Widget build(BuildContext context) {
    final int variance = actual - estimate;
    final Color color = variance <= 0 ? AppColors.green : AppColors.rose;
    return DashboardCard(
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: <Widget>[
          _summaryStat('Estimated', TimeEntry.formatMinutes(estimate), null),
          _summaryStat('Actual', TimeEntry.formatMinutes(actual), null),
          _summaryStat(
            'Variance',
            '${variance >= 0 ? '+' : '−'}'
                '${TimeEntry.formatMinutes(variance.abs())}',
            color,
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color? color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow({
    required this.task,
    required this.estimate,
    required this.actual,
  });
  final Task task;
  final int estimate;
  final int actual;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool over = estimate > 0 && actual > estimate;
    final Color color = over ? AppColors.rose : AppColors.green;
    // Fill relative to the estimate; when there's no estimate, show it full.
    final double ratio =
        estimate <= 0 ? 1 : (actual / estimate).clamp(0.0, 1.0);
    final int variance = actual - estimate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  estimate <= 0
                      ? '${TimeEntry.formatMinutes(actual)} (no estimate)'
                      : '${TimeEntry.formatMinutes(actual)} / '
                          '${TimeEntry.formatMinutes(estimate)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    fontFeatures:
                        const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                color: color,
              ),
            ),
            if (estimate > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                over
                    ? '${TimeEntry.formatMinutes(variance)} over estimate'
                    : variance == 0
                        ? 'On estimate'
                        : '${TimeEntry.formatMinutes(-variance)} remaining',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskDropdown extends StatelessWidget {
  const _TaskDropdown({
    required this.tasks,
    required this.value,
    required this.onChanged,
  });

  final List<Task> tasks;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: tasks.any((Task t) => t.id == value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, labelText: 'Task'),
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('No task')),
        for (final Task t in tasks)
          DropdownMenuItem<int?>(
            value: t.id,
            child: Text(t.title, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// The timesheet: entries grouped by day with a per-day total.
class _Timesheet extends ConsumerWidget {
  const _Timesheet({required this.entries});

  final List<TimeEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, List<TimeEntry>> byDay = <String, List<TimeEntry>>{};
    for (final TimeEntry e in entries) {
      byDay.putIfAbsent(ymd(e.startedAt.toLocal()), () => <TimeEntry>[]).add(e);
    }
    final List<String> days = byDay.keys.toList()
      ..sort((String a, String b) => b.compareTo(a));

    return ListView(
      children: <Widget>[
        for (final String day in days)
          _DaySection(day: byDay[day]!, label: _dayLabel(byDay[day]!.first)),
      ],
    );
  }

  String _dayLabel(TimeEntry sample) {
    final DateTime d = sample.startedAt.toLocal();
    final DateTime now = DateTime.now();
    if (sameDay(d, now)) {
      return 'Today';
    }
    if (sameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatLongDate(d);
  }
}

class _DaySection extends ConsumerWidget {
  const _DaySection({required this.day, required this.label});

  final List<TimeEntry> day;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = day.fold<int>(0, (int s, TimeEntry e) => s + e.minutes);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  TimeEntry.formatMinutes(total),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          DashboardCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < day.length; i++) ...<Widget>[
                  _EntryRow(entry: day[i]),
                  if (i != day.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry});

  final TimeEntry entry;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final bool? saved = await showTimeEntryDialog(context, existing: entry);
    if ((saved ?? false)) {
      ref.invalidate(myTimeEntriesProvider);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(timeEntriesRepositoryProvider).delete(entry.id);
    ref.invalidate(myTimeEntriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => _edit(context, ref),
      title: Text(
        entry.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: entry.taskTitle.isNotEmpty && entry.description.isNotEmpty
          ? Text(
              entry.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (entry.billable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.attach_money, size: 18, color: AppColors.green),
            ),
          Text(
            entry.durationLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
            onSelected: (String v) {
              if (v == 'edit') {
                _edit(context, ref);
              } else if (v == 'delete') {
                _delete(context, ref);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
          ),
        ],
      ),
    );
  }
}
