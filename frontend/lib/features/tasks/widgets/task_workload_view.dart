import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/task.dart';

/// Per-assignee workload, computed from the open tasks in the current list:
/// task count, story points and estimated hours, with a bar relative to the
/// busiest person (AGENTS.md §1 feature view).
class TaskWorkloadView extends StatelessWidget {
  const TaskWorkloadView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context) {
    final Map<String, _Load> byName = <String, _Load>{};
    for (final Task t in tasks) {
      if (t.done || t.parentId != null) {
        continue;
      }
      final List<String> names = t.assigneeNames.isEmpty
          ? const <String>['Unassigned']
          : t.assigneeNames;
      for (final String name in names) {
        final _Load load = byName.putIfAbsent(name, () => _Load(name));
        load.tasks++;
        load.points += t.points;
        load.minutes += t.estimateMinutes;
      }
    }
    if (byName.isEmpty) {
      return const Center(child: Text('No open work to chart yet.'));
    }
    final List<_Load> loads = byName.values.toList()
      ..sort((_Load a, _Load b) => b.tasks.compareTo(a.tasks));
    final int maxTasks = loads.first.tasks;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: loads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int i) =>
          _WorkloadRow(load: loads[i], maxTasks: maxTasks),
    );
  }
}

class _Load {
  _Load(this.name);

  final String name;
  int tasks = 0;
  int points = 0;
  int minutes = 0;

  double get hours => minutes / 60.0;
}

class _WorkloadRow extends StatelessWidget {
  const _WorkloadRow({required this.load, required this.maxTasks});

  final _Load load;
  final int maxTasks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double frac = maxTasks == 0 ? 0 : load.tasks / maxTasks;
    final Color color = frac > 0.85
        ? AppColors.rose
        : (frac >= 0.5 ? AppColors.amber : AppColors.green);
    final bool unassigned = load.name == 'Unassigned';
    return Row(
      children: <Widget>[
        if (unassigned)
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.person_off_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          UserAvatar(name: load.name, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      load.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    <String>[
                      '${load.tasks} ${load.tasks == 1 ? 'task' : 'tasks'}',
                      if (load.points > 0) '${load.points} pts',
                      if (load.minutes > 0)
                        '${load.hours.toStringAsFixed(1)} h',
                    ].join('  ·  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac.clamp(0.0, 1.0),
                  minHeight: 8,
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
