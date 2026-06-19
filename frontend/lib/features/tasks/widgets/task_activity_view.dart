import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/task.dart';

/// A chronological activity feed of tasks — most recently touched first,
/// grouped by day, with an icon for created / updated / completed
/// (AGENTS.md §1 feature view). Derived entirely from the task list.
class TaskActivityView extends StatelessWidget {
  const TaskActivityView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context) {
    final List<Task> ordered = <Task>[...tasks]
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));

    final List<Widget> rows = <Widget>[];
    DateTime? lastDay;
    for (final Task t in ordered) {
      final DateTime day = t.updatedAt.toLocal();
      if (lastDay == null || !sameDay(lastDay, day)) {
        rows.add(_DayHeader(day: day));
        lastDay = day;
      }
      rows.add(_ActivityRow(task: t, onTap: () => onTapTask(t)));
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String label = sameDay(day, now)
        ? 'Today'
        : sameDay(day, now.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : formatLongDate(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  ({IconData icon, Color color, String verb}) get _kind {
    if (task.done) {
      return (
        icon: Icons.check_circle,
        color: AppColors.green,
        verb: 'Completed',
      );
    }
    final bool isNew =
        task.updatedAt.difference(task.createdAt).inMinutes.abs() < 1;
    if (isNew) {
      return (
        icon: Icons.add_circle_outline,
        color: AppColors.sky,
        verb: 'Created',
      );
    }
    return (icon: Icons.edit_outlined, color: AppColors.amber, verb: 'Updated');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ({IconData icon, Color color, String verb}) k = _kind;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(k.icon, size: 20, color: k.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${k.verb} ',
                          style: TextStyle(
                            color: k.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (task.projectName != null) task.projectName!,
                      if (task.assigneeNames.isNotEmpty) task.assigneeLabel,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              relativeTime(task.updatedAt),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
