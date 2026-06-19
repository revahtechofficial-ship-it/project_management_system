import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/task.dart';

const double _labelW = 150;
const double _rowH = 34;
const double _barH = 18;

/// A horizontal, project-grouped timeline: each scheduled task is a bar from
/// its start to its due date, positioned proportionally across the overall
/// date range. Simpler than the dependency-aware Gantt (AGENTS.md §1 view).
class TaskTimelineView extends StatelessWidget {
  const TaskTimelineView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> dated = tasks
        .where(
          (Task t) =>
              t.parentId == null && (t.dueDate != null || t.startDate != null),
        )
        .toList(growable: false);
    if (dated.isEmpty) {
      return Center(
        child: Text(
          'No scheduled tasks yet. Add a start or due date to see them here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    DateTime min = _dayOf(dated.first, start: true);
    DateTime max = _dayOf(dated.first, start: false);
    for (final Task t in dated) {
      final DateTime s = _dayOf(t, start: true);
      final DateTime e = _dayOf(t, start: false);
      if (s.isBefore(min)) {
        min = s;
      }
      if (e.isAfter(max)) {
        max = e;
      }
    }
    min = min.subtract(const Duration(days: 2));
    max = max.add(const Duration(days: 2));
    final int spanDays = max.difference(min).inDays.clamp(1, 100000);

    final Map<String, List<Task>> groups = <String, List<Task>>{};
    for (final Task t in dated) {
      groups.putIfAbsent(t.projectName ?? 'No project', () => <Task>[]).add(t);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double trackW = (c.maxWidth - _labelW).clamp(140.0, 100000.0);
        double fracX(DateTime d) =>
            trackW * (d.difference(min).inDays / spanDays).clamp(0.0, 1.0);

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            _MonthHeader(min: min, max: max, trackW: trackW, fracX: fracX),
            const Divider(height: 1),
            for (final MapEntry<String, List<Task>> g
                in groups.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
                child: Text(
                  g.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final Task t in g.value)
                _TimelineRow(
                  task: t,
                  trackW: trackW,
                  fracX: fracX,
                  onTap: () => onTapTask(t),
                ),
            ],
          ],
        );
      },
    );
  }

  static DateTime _dayOf(Task t, {required bool start}) {
    final DateTime d =
        (start ? (t.startDate ?? t.dueDate) : (t.dueDate ?? t.startDate))!
            .toLocal();
    return DateTime(d.year, d.month, d.day);
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.min,
    required this.max,
    required this.trackW,
    required this.fracX,
  });

  final DateTime min;
  final DateTime max;
  final double trackW;
  final double Function(DateTime) fracX;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<DateTime> months = <DateTime>[];
    DateTime m = DateTime(min.year, min.month, 1);
    while (m.isBefore(max)) {
      if (!m.isBefore(min)) {
        months.add(m);
      }
      m = DateTime(m.year, m.month + 1, 1);
    }
    return Row(
      children: <Widget>[
        const SizedBox(width: _labelW),
        Expanded(
          child: SizedBox(
            height: 22,
            child: Stack(
              children: <Widget>[
                for (final DateTime d in months)
                  Positioned(
                    left: fracX(d),
                    top: 2,
                    child: Text(
                      monthYear(d),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
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
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.task,
    required this.trackW,
    required this.fracX,
    required this.onTap,
  });

  final Task task;
  final double trackW;
  final double Function(DateTime) fracX;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasRange = task.startDate != null && task.dueDate != null;
    final Color color = task.done
        ? AppColors.green
        : (task.dueDate != null &&
                  task.dueDate!.toLocal().isBefore(DateTime.now())
              ? AppColors.rose
              : AppColors.brand);

    Widget bar;
    if (hasRange) {
      final double left = fracX(TaskTimelineView._dayOf(task, start: true));
      final double right = fracX(TaskTimelineView._dayOf(task, start: false));
      bar = Positioned(
        left: left,
        top: (_rowH - _barH) / 2,
        child: Container(
          width: (right - left).clamp(8.0, trackW),
          height: _barH,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    } else {
      final double x = fracX(TaskTimelineView._dayOf(task, start: false));
      bar = Positioned(
        left: (x - _barH / 2).clamp(0.0, trackW),
        top: (_rowH - _barH) / 2,
        child: Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: _barH * 0.8,
            height: _barH * 0.8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowH,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: _labelW,
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  color: task.done ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            Expanded(child: Stack(children: <Widget>[bar])),
          ],
        ),
      ),
    );
  }
}
