import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/task.dart';

/// A month calendar that places tasks on their due date. Tapping a task calls
/// [onTapTask] (the page opens the edit dialog).
class TaskCalendarView extends StatefulWidget {
  const TaskCalendarView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final void Function(Task) onTapTask;

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime first = DateTime(_month.year, _month.month);
    final int offset = first.weekday - 1; // Monday = 0
    final DateTime gridStart = first.subtract(Duration(days: offset));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Text(
                monthYear(_month),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  final DateTime now = DateTime.now();
                  setState(() => _month = DateTime(now.year, now.month));
                },
                child: const Text('Today'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final String d in const <String>[
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int week = 0; week < 6; week++)
            SizedBox(
              height: 104,
              child: Row(
                children: <Widget>[
                  for (int day = 0; day < 7; day++)
                    Expanded(
                      child: _DayCell(
                        date: gridStart.add(Duration(days: week * 7 + day)),
                        month: _month.month,
                        tasks: widget.tasks,
                        onTapTask: widget.onTapTask,
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.month,
    required this.tasks,
    required this.onTapTask,
  });

  final DateTime date;
  final int month;
  final List<Task> tasks;
  final void Function(Task) onTapTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool inMonth = date.month == month;
    final bool isToday = sameDay(date, DateTime.now());
    final List<Task> dayTasks = tasks
        .where(
          (Task t) => t.dueDate != null && sameDay(t.dueDate!.toLocal(), date),
        )
        .toList();
    final List<Task> shown = dayTasks.take(3).toList();
    final int extra = dayTasks.length - shown.length;

    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: inMonth ? scheme.surface : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: isToday
                  ? const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? Colors.white
                      : inMonth
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          for (final Task t in shown) _MiniTask(task: t, onTap: onTapTask),
          if (extra > 0)
            Text(
              '+$extra more',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _MiniTask extends StatelessWidget {
  const _MiniTask({required this.task, required this.onTap});
  final Task task;
  final void Function(Task) onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = task.done ? AppColors.green : AppColors.brand;
    return GestureDetector(
      onTap: () => onTap(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: color,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
