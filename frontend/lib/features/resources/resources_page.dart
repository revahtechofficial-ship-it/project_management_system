import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/availability_entry.dart';
import '../../data/models/member_capacity.dart';
import '../../data/models/task.dart';
import '../tasks/providers/tasks_providers.dart';
import 'providers/resources_providers.dart';
import 'widgets/time_off_dialog.dart';

/// Resource Management: team workload and allocation against per-member
/// capacity, plus availability (time off) and a multi-week planning grid
/// (AGENTS.md §1 feature page).
class ResourcesPage extends ConsumerStatefulWidget {
  const ResourcesPage({super.key});

  @override
  ConsumerState<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends ConsumerState<ResourcesPage> {
  _Segment _segment = _Segment.workload;
  _Period _period = _Period.thisWeek;

  Future<void> _addTimeOff() async {
    final bool? saved = await showTimeOffDialog(context);
    if (saved == true && mounted) {
      setState(() {});
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
            title: 'Resources',
            subtitle: 'Workload, capacity and availability',
            actions: <Widget>[
              if (_segment == _Segment.availability)
                FilledButton.icon(
                  onPressed: _addTimeOff,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add time off'),
                )
              else
                _PeriodDropdown(
                  value: _period,
                  onChanged: (_Period p) => setState(() => _period = p),
                ),
              SegmentedButton<_Segment>(
                segments: const <ButtonSegment<_Segment>>[
                  ButtonSegment<_Segment>(
                    value: _Segment.workload,
                    icon: Icon(Icons.bar_chart_outlined, size: 18),
                    label: Text('Workload'),
                  ),
                  ButtonSegment<_Segment>(
                    value: _Segment.planning,
                    icon: Icon(Icons.grid_view_outlined, size: 18),
                    label: Text('Planning'),
                  ),
                  ButtonSegment<_Segment>(
                    value: _Segment.availability,
                    icon: Icon(Icons.event_busy_outlined, size: 18),
                    label: Text('Availability'),
                  ),
                ],
                selected: <_Segment>{_segment},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_Segment> s) =>
                    setState(() => _segment = s.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: switch (_segment) {
              _Segment.workload => _WorkloadView(period: _period),
              _Segment.planning => const _PlanningView(),
              _Segment.availability => _AvailabilityView(onAdd: _addTimeOff),
            },
          ),
        ],
      ),
    );
  }
}

enum _Segment { workload, planning, availability }

enum _Period {
  thisWeek('This week'),
  nextWeek('Next week'),
  thisMonth('This month');

  const _Period(this.label);

  final String label;

  /// The half-open date range [from, to) this period covers.
  (DateTime, DateTime) range(DateTime today) {
    switch (this) {
      case _Period.thisWeek:
        final DateTime from = _weekStart(today);
        return (from, from.add(const Duration(days: 7)));
      case _Period.nextWeek:
        final DateTime from = _weekStart(today).add(const Duration(days: 7));
        return (from, from.add(const Duration(days: 7)));
      case _Period.thisMonth:
        final DateTime from = DateTime(today.year, today.month, 1);
        return (from, DateTime(today.year, today.month + 1, 1));
    }
  }
}

// --- shared compute --------------------------------------------------------

DateTime _today() {
  final DateTime n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _weekStart(DateTime d) {
  final DateTime dd = DateTime(d.year, d.month, d.day);
  return dd.subtract(Duration(days: dd.weekday - 1));
}

/// Count of weekdays (Mon–Fri) in the half-open range [from, to).
int _weekdays(DateTime from, DateTime to) {
  int n = 0;
  DateTime d = from;
  while (d.isBefore(to)) {
    if (d.weekday <= 5) {
      n++;
    }
    d = d.add(const Duration(days: 1));
  }
  return n;
}

/// Weekdays in [from, to) the member is on leave, given their [off] entries.
int _offWeekdays(DateTime from, DateTime to, List<AvailabilityEntry> off) {
  int n = 0;
  DateTime d = from;
  while (d.isBefore(to)) {
    if (d.weekday <= 5 && off.any((AvailabilityEntry e) => e.covers(d))) {
      n++;
    }
    d = d.add(const Duration(days: 1));
  }
  return n;
}

class _Alloc {
  double minutes = 0;
  int tasks = 0;
  int overdue = 0;

  double get hours => minutes / 60.0;
}

/// Allocates the estimated effort of open, dated tasks to their assignees,
/// splitting each task's estimate evenly across them, for the window
/// [from, to).
Map<int, _Alloc> _allocate(
  List<Task> tasks,
  DateTime from,
  DateTime to,
  DateTime today,
) {
  final Map<int, _Alloc> byUser = <int, _Alloc>{};
  for (final Task t in tasks) {
    if (t.done || t.parentId != null || t.assigneeIds.isEmpty) {
      continue;
    }
    final DateTime? due = t.dueDate?.toLocal();
    if (due == null) {
      continue;
    }
    final DateTime d = DateTime(due.year, due.month, due.day);
    if (d.isBefore(from) || !d.isBefore(to)) {
      continue;
    }
    final double share = t.estimateMinutes / t.assigneeIds.length;
    final bool overdue = d.isBefore(today);
    for (final int id in t.assigneeIds) {
      final _Alloc a = byUser.putIfAbsent(id, () => _Alloc());
      a.minutes += share;
      a.tasks++;
      if (overdue) {
        a.overdue++;
      }
    }
  }
  return byUser;
}

/// A member's capacity (hours) for [from, to) after subtracting leave.
double _capacityHours(
  int weeklyHours,
  DateTime from,
  DateTime to,
  List<AvailabilityEntry> off,
) {
  final int workdays = _weekdays(from, to);
  final int leave = _offWeekdays(from, to, off);
  final int available = (workdays - leave).clamp(0, workdays);
  return weeklyHours / 5.0 * available;
}

Color _utilColor(double util) {
  if (util > 1.0) {
    return AppColors.rose;
  }
  if (util >= 0.85) {
    return AppColors.amber;
  }
  if (util > 0) {
    return AppColors.green;
  }
  return AppColors.slate;
}

Map<int, List<AvailabilityEntry>> _offByUser(List<AvailabilityEntry> all) {
  final Map<int, List<AvailabilityEntry>> out =
      <int, List<AvailabilityEntry>>{};
  for (final AvailabilityEntry e in all) {
    out.putIfAbsent(e.userId, () => <AvailabilityEntry>[]).add(e);
  }
  return out;
}

// --- Workload --------------------------------------------------------------

class _WorkloadView extends ConsumerWidget {
  const _WorkloadView({required this.period});

  final _Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final List<MemberCapacity> caps =
        ref.watch(capacityProvider).asData?.value ?? const <MemberCapacity>[];
    final List<AvailabilityEntry> off =
        ref.watch(availabilityProvider).asData?.value ??
        const <AvailabilityEntry>[];

    if (caps.isEmpty) {
      return ref.watch(capacityProvider).isLoading
          ? const LoadingView()
          : const EmptyState(
              icon: Icons.group_off_rounded,
              message: 'No team members with capacity set yet.',
            );
    }

    final DateTime today = _today();
    final (DateTime from, DateTime to) = period.range(today);
    final Map<int, _Alloc> alloc = _allocate(tasks, from, to, today);
    final Map<int, List<AvailabilityEntry>> offByUser = _offByUser(off);

    int unscheduled = 0;
    for (final Task t in tasks) {
      if (!t.done &&
          t.parentId == null &&
          t.assigneeIds.isNotEmpty &&
          t.dueDate == null) {
        unscheduled++;
      }
    }

    final List<_Row> rows = <_Row>[
      for (final MemberCapacity c in caps)
        _Row(
          cap: c,
          alloc: alloc[c.userId] ?? _Alloc(),
          capacityHours: _capacityHours(
            c.weeklyHours,
            from,
            to,
            offByUser[c.userId] ?? const <AvailabilityEntry>[],
          ),
          leaveDays: _offWeekdays(
            from,
            to,
            offByUser[c.userId] ?? const <AvailabilityEntry>[],
          ),
        ),
    ]..sort((_Row a, _Row b) => b.util.compareTo(a.util));

    final double totalAlloc = rows.fold(
      0,
      (double s, _Row r) => s + r.alloc.hours,
    );
    final double totalCap = rows.fold(
      0,
      (double s, _Row r) => s + r.capacityHours,
    );
    final int over = rows.where((_Row r) => r.util > 1.0).length;
    final int onLeave = rows.where((_Row r) => r.leaveDays > 0).length;

    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _StatChip(
              label: 'Allocated',
              value: '${totalAlloc.toStringAsFixed(0)}h',
              color: AppColors.sky,
            ),
            _StatChip(
              label: 'Capacity',
              value: '${totalCap.toStringAsFixed(0)}h',
              color: AppColors.teal,
            ),
            _StatChip(
              label: 'Over capacity',
              value: '$over',
              color: over > 0 ? AppColors.rose : AppColors.slate,
            ),
            _StatChip(
              label: 'On leave',
              value: '$onLeave',
              color: onLeave > 0 ? AppColors.amber : AppColors.slate,
            ),
            if (unscheduled > 0)
              _StatChip(
                label: 'No due date',
                value: '$unscheduled',
                color: AppColors.slate,
              ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'Allocation vs capacity · ${period.label}',
          child: Column(
            children: <Widget>[
              for (final _Row r in rows) _MemberWorkloadRow(row: r),
            ],
          ),
        ),
      ],
    );
  }
}

/// One member's computed workload for the selected window.
class _Row {
  _Row({
    required this.cap,
    required this.alloc,
    required this.capacityHours,
    required this.leaveDays,
  });

  final MemberCapacity cap;
  final _Alloc alloc;
  final double capacityHours;
  final int leaveDays;

  double get util => capacityHours <= 0
      ? (alloc.hours > 0 ? 2.0 : 0)
      : alloc.hours / capacityHours;
}

class _MemberWorkloadRow extends StatelessWidget {
  const _MemberWorkloadRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double util = row.util;
    final Color color = _utilColor(util);
    final bool fullyOff = row.capacityHours <= 0 && row.leaveDays > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar(name: row.cap.displayName, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        row.cap.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      fullyOff
                          ? 'On leave'
                          : '${row.alloc.hours.toStringAsFixed(1)}h / '
                                '${row.capacityHours.toStringAsFixed(0)}h',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        fullyOff ? '' : '${(util * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: util.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    '${row.alloc.tasks} ${row.alloc.tasks == 1 ? 'task' : 'tasks'}',
                    if (row.alloc.overdue > 0) '${row.alloc.overdue} overdue',
                    if (row.leaveDays > 0)
                      '${row.leaveDays} leave ${row.leaveDays == 1 ? 'day' : 'days'}',
                  ].join('  ·  '),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Planning grid ---------------------------------------------------------

class _PlanningView extends ConsumerWidget {
  const _PlanningView();

  static const int _weeks = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final List<MemberCapacity> caps =
        ref.watch(capacityProvider).asData?.value ?? const <MemberCapacity>[];
    final List<AvailabilityEntry> off =
        ref.watch(availabilityProvider).asData?.value ??
        const <AvailabilityEntry>[];

    if (caps.isEmpty) {
      return ref.watch(capacityProvider).isLoading
          ? const LoadingView()
          : const EmptyState(
              icon: Icons.group_off_rounded,
              message: 'No team members with capacity set yet.',
            );
    }

    final DateTime today = _today();
    final DateTime start = _weekStart(today);
    final List<DateTime> weekStarts = <DateTime>[
      for (int i = 0; i < _weeks; i++) start.add(Duration(days: 7 * i)),
    ];
    final Map<int, List<AvailabilityEntry>> offByUser = _offByUser(off);

    return DashboardCard(
      title: 'Weekly utilization · next $_weeks weeks',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 180),
                for (final DateTime w in weekStarts)
                  SizedBox(
                    width: 64,
                    child: Text(
                      shortDate(w),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final MemberCapacity c in caps)
              _PlanningRow(
                cap: c,
                weekStarts: weekStarts,
                tasks: tasks,
                today: today,
                off: offByUser[c.userId] ?? const <AvailabilityEntry>[],
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanningRow extends StatelessWidget {
  const _PlanningRow({
    required this.cap,
    required this.weekStarts,
    required this.tasks,
    required this.today,
    required this.off,
  });

  final MemberCapacity cap;
  final List<DateTime> weekStarts;
  final List<Task> tasks;
  final DateTime today;
  final List<AvailabilityEntry> off;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 180,
            child: Row(
              children: <Widget>[
                UserAvatar(name: cap.displayName, radius: 13),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cap.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          for (final DateTime w in weekStarts)
            _PlanningCell(
              cap: cap,
              from: w,
              to: w.add(const Duration(days: 7)),
              tasks: tasks,
              today: today,
              off: off,
            ),
        ],
      ),
    );
  }
}

class _PlanningCell extends StatelessWidget {
  const _PlanningCell({
    required this.cap,
    required this.from,
    required this.to,
    required this.tasks,
    required this.today,
    required this.off,
  });

  final MemberCapacity cap;
  final DateTime from;
  final DateTime to;
  final List<Task> tasks;
  final DateTime today;
  final List<AvailabilityEntry> off;

  @override
  Widget build(BuildContext context) {
    final double capHours = _capacityHours(cap.weeklyHours, from, to, off);
    final double allocHours =
        (_allocate(tasks, from, to, today)[cap.userId]?.hours) ?? 0;
    final bool fullyOff = capHours <= 0 && _offWeekdays(from, to, off) > 0;
    final double util = capHours <= 0
        ? (allocHours > 0 ? 2.0 : 0)
        : allocHours / capHours;
    final Color color = fullyOff ? AppColors.violet : _utilColor(util);
    return Container(
      width: 60,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: util <= 0 && !fullyOff ? 0.06 : 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: fullyOff
          ? Icon(Icons.event_busy_outlined, size: 16, color: color)
          : Text(
              util <= 0 ? '–' : '${(util * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
    );
  }
}

// --- Availability ----------------------------------------------------------

class _AvailabilityView extends ConsumerWidget {
  const _AvailabilityView({required this.onAdd});

  final VoidCallback onAdd;

  Future<void> _delete(WidgetRef ref, int id) async {
    await ref.read(resourcesRepositoryProvider).deleteAvailability(id);
    ref.invalidate(availabilityProvider);
  }

  Future<void> _setCapacity(WidgetRef ref, int userId, int hours) async {
    await ref.read(resourcesRepositoryProvider).setCapacity(userId, hours);
    ref.invalidate(capacityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = _today();
    final List<AvailabilityEntry> off =
        (ref.watch(availabilityProvider).asData?.value ??
                const <AvailabilityEntry>[])
            .where((AvailabilityEntry e) => !e.endDate.isBefore(today))
            .toList()
          ..sort(
            (AvailabilityEntry a, AvailabilityEntry b) =>
                a.startDate.compareTo(b.startDate),
          );
    final List<MemberCapacity> caps =
        ref.watch(capacityProvider).asData?.value ?? const <MemberCapacity>[];

    return ListView(
      children: <Widget>[
        DashboardCard(
          title: 'Upcoming time off',
          child: off.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.event_available_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No time off scheduled. Use “Add time off” to plan '
                          'around leave.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (final AvailabilityEntry e in off)
                      _TimeOffRow(entry: e, onDelete: () => _delete(ref, e.id)),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'Weekly capacity',
          child: caps.isEmpty
              ? const EmptyState(
                  icon: Icons.group_off_rounded,
                  message: 'No team members with capacity set yet.',
                )
              : Column(
                  children: <Widget>[
                    for (final MemberCapacity c in caps)
                      _CapacityRow(
                        cap: c,
                        onChanged: (int h) => _setCapacity(ref, c.userId, h),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TimeOffRow extends StatelessWidget {
  const _TimeOffRow({required this.entry, required this.onDelete});

  final AvailabilityEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool single = entry.startDate == entry.endDate;
    final String range = single
        ? shortDate(entry.startDate)
        : '${shortDate(entry.startDate)} – ${shortDate(entry.endDate)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          UserAvatar(name: entry.userName, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.userName.isEmpty ? 'Member' : entry.userName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  entry.note.isEmpty ? range : '$range · ${entry.note}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: entry.kind.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(entry.kind.icon, size: 14, color: entry.kind.color),
                const SizedBox(width: 6),
                Text(
                  entry.kind.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: entry.kind.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            color: scheme.onSurfaceVariant,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({required this.cap, required this.onChanged});

  final MemberCapacity cap;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          UserAvatar(name: cap.displayName, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cap.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: cap.weeklyHours <= 0
                ? null
                : () => onChanged((cap.weeklyHours - 5).clamp(0, 80)),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${cap.weeklyHours}h',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: cap.weeklyHours >= 80
                ? null
                : () => onChanged((cap.weeklyHours + 5).clamp(0, 80)),
          ),
          Text('/wk', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// --- small widgets ---------------------------------------------------------

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({required this.value, required this.onChanged});

  final _Period value;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Period>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          items: <DropdownMenuItem<_Period>>[
            for (final _Period p in _Period.values)
              DropdownMenuItem<_Period>(value: p, child: Text(p.label)),
          ],
          onChanged: (_Period? p) {
            if (p != null) {
              onChanged(p);
            }
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
