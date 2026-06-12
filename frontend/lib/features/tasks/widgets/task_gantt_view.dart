import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/enums/dependency_type.dart';
import '../../../data/models/milestone.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_dependency.dart';
import '../../../providers/auth_provider.dart';
import '../providers/dependencies_providers.dart';
import '../providers/milestones_providers.dart';
import '../providers/tasks_providers.dart';
import 'milestones_dialog.dart';

const double _dayWidth = 36;
const double _labelWidth = 170;
const double _headerHeight = 36;
const double _rowHeight = 44;
const double _barHeight = 24;

DateTime _dateOnly(DateTime d) {
  final DateTime l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

typedef _Span = ({DateTime start, DateTime end});
typedef _Pos = ({int row, int startOffset, int span});

/// A Gantt timeline with dependency arrows and critical-path highlighting.
/// Long-press a bar and drag to reschedule (successors auto-shift on the
/// server); tap a bar to edit.
class TaskGanttView extends ConsumerStatefulWidget {
  const TaskGanttView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final void Function(Task) onTapTask;

  @override
  ConsumerState<TaskGanttView> createState() => _TaskGanttViewState();
}

class _TaskGanttViewState extends ConsumerState<TaskGanttView> {
  int? _dragId;
  double _dragDx = 0;

  _Span? _span(Task t) {
    final DateTime? s = t.startDate ?? t.dueDate;
    final DateTime? e = t.dueDate ?? t.startDate;
    if (s == null || e == null) {
      return null;
    }
    DateTime start = _dateOnly(s);
    DateTime end = _dateOnly(e);
    if (end.isBefore(start)) {
      final DateTime tmp = start;
      start = end;
      end = tmp;
    }
    return (start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TaskDependency> deps =
        ref.watch(dependenciesProvider).asData?.value ??
            const <TaskDependency>[];
    final List<Task> scheduled = widget.tasks
        .where((Task t) => t.startDate != null || t.dueDate != null)
        .toList();

    if (scheduled.isEmpty) {
      return const EmptyState(
        icon: Icons.view_timeline_outlined,
        message: 'No scheduled tasks yet.\n'
            'Add a start or due date to a task to see it here.',
      );
    }

    DateTime min = _span(scheduled.first)!.start;
    DateTime max = _span(scheduled.first)!.end;
    final Map<int, _Span> spanById = <int, _Span>{};
    for (final Task t in scheduled) {
      final _Span s = _span(t)!;
      spanById[t.id] = s;
      if (s.start.isBefore(min)) {
        min = s.start;
      }
      if (s.end.isAfter(max)) {
        max = s.end;
      }
    }
    final DateTime rangeStart = min.subtract(const Duration(days: 2));
    final DateTime rangeEnd = max.add(const Duration(days: 3));
    final int days = rangeEnd.difference(rangeStart).inDays + 1;
    final double total = days * _dayWidth;
    final double bodyHeight = _headerHeight + scheduled.length * _rowHeight;

    final Map<int, _Pos> pos = <int, _Pos>{};
    for (int i = 0; i < scheduled.length; i++) {
      final _Span s = spanById[scheduled[i].id]!;
      pos[scheduled[i].id] = (
        row: i,
        startOffset: s.start.difference(rangeStart).inDays,
        span: s.end.difference(s.start).inDays + 1,
      );
    }

    final Set<int> critical = _criticalPath(scheduled, spanById, deps);
    final List<_Arrow> arrows = _arrows(deps, pos, critical);

    final List<Milestone> milestones =
        ref.watch(milestonesProvider).asData?.value ?? const <Milestone>[];
    final List<Milestone> visibleMs = milestones.where((Milestone m) {
      final DateTime d = _dateOnly(m.dueDate);
      return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (ref.watch(authControllerProvider).asData?.value.isAdmin ??
                  false)
                FilledButton.tonalIcon(
                  onPressed: () => _setBaseline(context),
                  icon: const Icon(Icons.flag_circle_outlined, size: 18),
                  label: const Text('Set baseline'),
                ),
              OutlinedButton.icon(
                onPressed: () => _openMilestones(context),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Milestones'),
              ),
              const SizedBox(width: 4),
              const _LegendSwatch(
                  color: AppColors.amber, label: 'Critical'),
              _LegendLine(color: scheme.onSurfaceVariant),
              const _LegendBaseline(),
              const _LegendMilestone(),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _LabelColumn(
                  tasks: scheduled,
                  critical: critical,
                  onTapTask: widget.onTapTask,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: total,
                      height: bodyHeight,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPainter(
                                days: days,
                                rows: scheduled.length,
                                rangeStart: rangeStart,
                                line: scheme.outlineVariant,
                                weekend: scheme.surfaceContainerLowest,
                              ),
                            ),
                          ),
                          Column(
                            children: <Widget>[
                              _DateHeader(
                                  days: days, rangeStart: rangeStart),
                              for (final Task t in scheduled)
                                _BarRow(
                                  task: t,
                                  span: spanById[t.id]!,
                                  rangeStart: rangeStart,
                                  critical: critical.contains(t.id),
                                  baselineStart: t.baselineStart,
                                  baselineDue: t.baselineDue,
                                  dragDx: _dragId == t.id ? _dragDx : 0,
                                  onTap: () => widget.onTapTask(t),
                                  onDragStart: () => setState(() {
                                    _dragId = t.id;
                                    _dragDx = 0;
                                  }),
                                  onDragUpdate: (double dx) =>
                                      setState(() => _dragDx = dx),
                                  onDragEnd: () => _commitDrag(t),
                                ),
                            ],
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ArrowPainter(
                                  arrows: arrows,
                                  normal: scheme.onSurfaceVariant,
                                  critical: AppColors.amber,
                                ),
                              ),
                            ),
                          ),
                          ..._milestoneMarkers(visibleMs, rangeStart),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setBaseline(BuildContext context) async {
    await ref.read(tasksRepositoryProvider).setBaseline();
    ref.invalidate(tasksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Baseline saved — planned dates snapshotted')),
      );
    }
  }

  Future<void> _openMilestones(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => const MilestonesDialog(),
    );
    ref.invalidate(milestonesProvider);
  }

  List<_Arrow> _arrows(
    List<TaskDependency> deps,
    Map<int, _Pos> pos,
    Set<int> critical,
  ) {
    final List<_Arrow> out = <_Arrow>[];
    for (final TaskDependency d in deps) {
      final _Pos? p = pos[d.predecessorId];
      final _Pos? s = pos[d.successorId];
      if (p == null || s == null) {
        continue;
      }
      final double pLeft = p.startOffset * _dayWidth + 2;
      final double pRight = pLeft + p.span * _dayWidth - 4;
      final double sLeft = s.startOffset * _dayWidth + 2;
      final double sRight = sLeft + s.span * _dayWidth - 4;
      final bool fromFinish = d.type == DependencyType.finishToStart ||
          d.type == DependencyType.finishToFinish;
      final bool toStart = d.type == DependencyType.finishToStart ||
          d.type == DependencyType.startToStart;
      out.add(_Arrow(
        fromX: fromFinish ? pRight : pLeft,
        fromY: _headerHeight + p.row * _rowHeight + _rowHeight / 2,
        toX: toStart ? sLeft : sRight,
        toY: _headerHeight + s.row * _rowHeight + _rowHeight / 2,
        critical: critical.contains(d.predecessorId) &&
            critical.contains(d.successorId),
      ));
    }
    return out;
  }

  Future<void> _commitDrag(Task t) async {
    final int delta = (_dragDx / _dayWidth).round();
    setState(() {
      _dragId = null;
      _dragDx = 0;
    });
    if (delta == 0) {
      return;
    }
    final Duration shift = Duration(days: delta);
    try {
      await ref.read(tasksRepositoryProvider).update(
            t.id,
            title: t.title,
            description: t.description,
            projectId: t.projectId,
            assigneeId: t.assigneeId,
            startDate: t.startDate?.add(shift),
            dueDate: t.dueDate?.add(shift),
            status: t.status,
            recurrence: t.recurrence,
            priority: t.priority,
            tags: t.tags,
          );
      ref.invalidate(tasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reschedule failed: $e')),
        );
      }
    }
  }
}

/// Critical Path Method over the dependency subgraph (tasks involved in at
/// least one link). Returns the ids of tasks with zero slack.
Set<int> _criticalPath(
  List<Task> scheduled,
  Map<int, _Span> spanById,
  List<TaskDependency> deps,
) {
  final Set<int> ids = <int>{};
  for (final TaskDependency d in deps) {
    if (spanById.containsKey(d.predecessorId) &&
        spanById.containsKey(d.successorId)) {
      ids
        ..add(d.predecessorId)
        ..add(d.successorId);
    }
  }
  if (ids.isEmpty) {
    return <int>{};
  }
  final Map<int, int> dur = <int, int>{
    for (final int id in ids)
      id: math.max(
          1, spanById[id]!.end.difference(spanById[id]!.start).inDays),
  };
  final Map<int, List<int>> succs = <int, List<int>>{};
  final Map<int, List<int>> preds = <int, List<int>>{};
  final Map<int, int> indeg = <int, int>{for (final int id in ids) id: 0};
  for (final TaskDependency d in deps) {
    if (!ids.contains(d.predecessorId) || !ids.contains(d.successorId)) {
      continue;
    }
    succs.putIfAbsent(d.predecessorId, () => <int>[]).add(d.successorId);
    preds.putIfAbsent(d.successorId, () => <int>[]).add(d.predecessorId);
    indeg[d.successorId] = (indeg[d.successorId] ?? 0) + 1;
  }
  final List<int> queue = <int>[
    for (final int id in ids)
      if (indeg[id] == 0) id
  ];
  final List<int> order = <int>[];
  final Map<int, int> ind = Map<int, int>.of(indeg);
  while (queue.isNotEmpty) {
    final int n = queue.removeAt(0);
    order.add(n);
    for (final int s in succs[n] ?? const <int>[]) {
      ind[s] = ind[s]! - 1;
      if (ind[s] == 0) {
        queue.add(s);
      }
    }
  }
  if (order.length != ids.length) {
    return <int>{}; // cycle guard (the API prevents this)
  }
  final Map<int, int> es = <int, int>{};
  final Map<int, int> ef = <int, int>{};
  for (final int n in order) {
    int s = 0;
    for (final int p in preds[n] ?? const <int>[]) {
      s = math.max(s, ef[p]!);
    }
    es[n] = s;
    ef[n] = s + dur[n]!;
  }
  final int projectEnd =
      ef.values.fold<int>(0, (int a, int b) => math.max(a, b));
  final Map<int, int> ls = <int, int>{};
  for (final int n in order.reversed) {
    int f = projectEnd;
    final List<int> sc = succs[n] ?? const <int>[];
    if (sc.isNotEmpty) {
      f = sc.map((int s) => ls[s]!).reduce(math.min);
    }
    ls[n] = f - dur[n]!;
  }
  return <int>{
    for (final int n in ids)
      if (ls[n]! - es[n]! <= 0) n
  };
}

class _Arrow {
  const _Arrow({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.critical,
  });
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final bool critical;
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 12,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.arrow_right_alt, size: 18, color: color),
        const SizedBox(width: 4),
        Text('Dependency',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LabelColumn extends StatelessWidget {
  const _LabelColumn({
    required this.tasks,
    required this.critical,
    required this.onTapTask,
  });
  final List<Task> tasks;
  final Set<int> critical;
  final void Function(Task) onTapTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _labelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: _headerHeight),
          for (final Task t in tasks)
            InkWell(
              onTap: () => onTapTask(t),
              child: Container(
                height: _rowHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    if (critical.contains(t.id)) ...<Widget>[
                      const Icon(Icons.bolt,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.days, required this.rangeStart});
  final int days;
  final DateTime rangeStart;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < days; i++)
            SizedBox(
              width: _dayWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    weekdayShort(
                            rangeStart.add(Duration(days: i)).weekday)[0],
                    style: TextStyle(
                        fontSize: 9, color: scheme.onSurfaceVariant),
                  ),
                  Text('${rangeStart.add(Duration(days: i)).day}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.task,
    required this.span,
    required this.rangeStart,
    required this.critical,
    required this.baselineStart,
    required this.baselineDue,
    required this.dragDx,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Task task;
  final _Span span;
  final DateTime rangeStart;
  final bool critical;
  final DateTime? baselineStart;
  final DateTime? baselineDue;
  final double dragDx;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(double) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int startOffset = span.start.difference(rangeStart).inDays;
    final int spanDays = span.end.difference(span.start).inDays + 1;
    final double left = startOffset * _dayWidth + 2 + dragDx;
    final double width = spanDays * _dayWidth - 4;

    final bool overdue = !task.done &&
        task.dueDate != null &&
        _dateOnly(task.dueDate!).isBefore(_dateOnly(DateTime.now()));
    final Color color = task.done
        ? AppColors.green
        : overdue
            ? AppColors.rose
            : AppColors.brand;

    return SizedBox(
      height: _rowHeight,
      child: Stack(
        children: <Widget>[
          if (baselineStart != null && baselineDue != null)
            _baselineBar(scheme),
          Positioned(
            left: left,
            top: (_rowHeight - _barHeight) / 2,
            child: GestureDetector(
              onTap: onTap,
              onLongPressStart: (_) => onDragStart(),
              onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) =>
                  onDragUpdate(d.offsetFromOrigin.dx),
              onLongPressEnd: (_) => onDragEnd(),
              child: Container(
                width: width,
                height: _barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                  border: critical
                      ? Border.all(color: AppColors.amber, width: 2.5)
                      : null,
                ),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baselineBar(ColorScheme scheme) {
    DateTime bs = _dateOnly(baselineStart!);
    DateTime be = _dateOnly(baselineDue!);
    if (be.isBefore(bs)) {
      final DateTime tmp = bs;
      bs = be;
      be = tmp;
    }
    final int offset = bs.difference(rangeStart).inDays;
    final int days = be.difference(bs).inDays + 1;
    final double w = days * _dayWidth - 4;
    return Positioned(
      left: offset * _dayWidth + 2,
      top: _rowHeight - 11,
      child: Container(
        width: w < 2 ? 2 : w,
        height: 5,
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Builds the vertical line + flag for each milestone in range (as `Positioned`
/// children of the timeline `Stack`).
List<Widget> _milestoneMarkers(
    List<Milestone> milestones, DateTime rangeStart) {
  final List<Widget> out = <Widget>[];
  for (final Milestone m in milestones) {
    final int offset = _dateOnly(m.dueDate).difference(rangeStart).inDays;
    final double x = offset * _dayWidth + _dayWidth / 2;
    final Color color = m.done ? AppColors.green : AppColors.rose;
    out.add(Positioned(
      left: x - 1,
      top: _headerHeight,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: color.withValues(alpha: 0.55)),
      ),
    ));
    out.add(Positioned(
      left: x + 3,
      top: 3,
      child: _MilestoneFlag(name: m.name, color: color),
    ));
  }
  return out;
}

class _MilestoneFlag extends StatelessWidget {
  const _MilestoneFlag({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.flag, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendBaseline extends StatelessWidget {
  const _LegendBaseline();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 5,
          decoration: BoxDecoration(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('Baseline',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LegendMilestone extends StatelessWidget {
  const _LegendMilestone();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.flag, size: 14, color: AppColors.rose),
        const SizedBox(width: 4),
        Text('Milestone',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.days,
    required this.rows,
    required this.rangeStart,
    required this.line,
    required this.weekend,
  });

  final int days;
  final int rows;
  final DateTime rangeStart;
  final Color line;
  final Color weekend;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = line
      ..strokeWidth = 1;
    final Paint weekendPaint = Paint()..color = weekend;

    for (int i = 0; i < days; i++) {
      final DateTime d = rangeStart.add(Duration(days: i));
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        canvas.drawRect(
          Rect.fromLTWH(i * _dayWidth, 0, _dayWidth, size.height),
          weekendPaint,
        );
      }
    }
    for (int i = 0; i <= days; i++) {
      final double x = i * _dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    canvas.drawLine(Offset(0, _headerHeight),
        Offset(size.width, _headerHeight), linePaint);
    for (int r = 1; r <= rows; r++) {
      final double y = _headerHeight + r * _rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.days != days || old.rows != rows || old.rangeStart != rangeStart;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.arrows,
    required this.normal,
    required this.critical,
  });

  final List<_Arrow> arrows;
  final Color normal;
  final Color critical;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Arrow a in arrows) {
      final Color c = a.critical ? critical : normal;
      final Paint p = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = a.critical ? 2 : 1.3;
      const double pad = 10;
      final Path path = Path()
        ..moveTo(a.fromX, a.fromY)
        ..lineTo(a.fromX + pad, a.fromY)
        ..lineTo(a.fromX + pad, a.toY)
        ..lineTo(a.toX - 4, a.toY);
      canvas.drawPath(path, p);
      // Arrowhead pointing right into the target.
      final Path head = Path()
        ..moveTo(a.toX, a.toY)
        ..lineTo(a.toX - 6, a.toY - 4)
        ..lineTo(a.toX - 6, a.toY + 4)
        ..close();
      canvas.drawPath(head, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => true;
}
