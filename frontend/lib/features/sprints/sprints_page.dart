import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/enums/sprint_status.dart';
import '../../data/models/sprint.dart';
import '../../data/models/task.dart';
import '../tasks/providers/tasks_providers.dart';
import '../tasks/widgets/task_board_view.dart';
import '../tasks/widgets/task_form_dialog.dart';
import 'providers/sprints_providers.dart';
import 'widgets/retro_dialog.dart';
import 'widgets/sprint_burndown.dart';
import 'widgets/sprint_form_dialog.dart';
import 'widgets/sprint_velocity.dart';

/// Sprint planning + execution: manage sprints, run the active one as a board,
/// and pull tasks from the backlog (AGENTS.md §1 feature page).
class SprintsPage extends ConsumerStatefulWidget {
  const SprintsPage({super.key});

  @override
  ConsumerState<SprintsPage> createState() => _SprintsPageState();
}

class _SprintsPageState extends ConsumerState<SprintsPage> {
  int? _selectedId;

  Sprint? _resolveSelected(List<Sprint> sprints) {
    if (sprints.isEmpty) {
      return null;
    }
    for (final Sprint s in sprints) {
      if (s.id == _selectedId) {
        return s;
      }
    }
    return sprints.firstWhere(
      (Sprint s) => s.status == SprintStatus.active,
      orElse: () => sprints.first,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(sprintsProvider);
    ref.invalidate(tasksProvider);
  }

  Future<void> _newSprint() async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const SprintFormDialog(),
    );
  }

  Future<void> _editSprint(Sprint sprint) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => SprintFormDialog(sprint: sprint),
    );
  }

  Future<void> _editTask(Task task) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => TaskFormDialog(task: task),
    );
    if (saved ?? false) {
      await _refresh();
    }
  }

  Future<void> _start(Sprint sprint) async {
    await ref.read(sprintsRepositoryProvider).start(sprint.id);
    await _refresh();
  }

  Future<void> _complete(Sprint sprint) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Complete "${sprint.name}"?'),
            content: const Text(
              'The sprint is marked done and any unfinished tasks move '
              'back to the backlog.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Complete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    await ref.read(sprintsRepositoryProvider).complete(sprint.id);
    await _refresh();
  }

  Future<void> _delete(Sprint sprint) async {
    final bool ok = await confirmDelete(
      context,
      what: '"${sprint.name}"',
      message: 'The sprint is removed; its tasks return to the backlog.',
    );
    if (!ok) {
      return;
    }
    await ref.read(sprintsRepositoryProvider).delete(sprint.id);
    await _refresh();
  }

  Future<void> _addToSprint(Task task, int sprintId) async {
    await ref.read(tasksRepositoryProvider).setSprint(task.id, sprintId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final List<Sprint> sprints =
        ref.watch(sprintsProvider).asData?.value ?? const <Sprint>[];
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final bool loading = ref.watch(sprintsProvider).isLoading;
    final Sprint? selected = _resolveSelected(sprints);

    final List<Task> backlog = tasks
        .where((Task t) => t.sprintId == null && t.parentId == null && !t.done)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Sprints',
          subtitle: 'Plan and run iterations',
          actions: <Widget>[
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            FilledButton.icon(
              onPressed: _newSprint,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New sprint'),
            ),
          ],
        ),
        if (loading) const LoadingBar(),
        const SizedBox(height: 20),
        if (sprints.isEmpty && !loading)
          const EmptyState(
            icon: Icons.directions_run,
            message: 'No sprints yet. Create one to start planning.',
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              for (final Sprint s in sprints)
                SizedBox(
                  width: 320,
                  child: _SprintCard(
                    sprint: s,
                    selected: selected?.id == s.id,
                    onSelect: () => setState(() => _selectedId = s.id),
                    onEdit: () => _editSprint(s),
                    onStart: () => _start(s),
                    onComplete: () => _complete(s),
                    onDelete: () => _delete(s),
                    onRetro: () =>
                        showSprintRetroDialog(context, s.id, s.name),
                  ),
                ),
            ],
          ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 24),
          _SprintBoardHeader(sprint: selected),
          const SizedBox(height: 12),
          SizedBox(
            height: 480,
            child: TaskBoardView(
              tasks: tasks
                  .where(
                    (Task t) => t.sprintId == selected.id && t.parentId == null,
                  )
                  .toList(growable: false),
              onTapTask: _editTask,
            ),
          ),
          const SizedBox(height: 24),
          DashboardCard(
            title: 'Burndown · ${selected.name}',
            child: SprintBurndown(sprint: selected, tasks: tasks),
          ),
        ],
        if (sprints.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          DashboardCard(
            title: 'Velocity',
            child: SprintVelocity(sprints: sprints),
          ),
        ],
        const SizedBox(height: 24),
        DashboardCard(
          title: 'Backlog (${backlog.length})',
          child: _Backlog(
            tasks: backlog,
            targetSprint: selected,
            onAdd: _addToSprint,
            onEdit: _editTask,
          ),
        ),
      ],
    );
  }
}

class _SprintCard extends StatelessWidget {
  const _SprintCard({
    required this.sprint,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onStart,
    required this.onComplete,
    required this.onDelete,
    required this.onRetro,
  });

  final Sprint sprint;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onRetro;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int? days = sprint.daysLeft;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brand : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusPill(
                    label: sprint.status.label,
                    color: sprint.status.color,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Sprint actions',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    onSelected: (String v) {
                      switch (v) {
                        case 'start':
                          onStart();
                        case 'complete':
                          onComplete();
                        case 'retro':
                          onRetro();
                        case 'edit':
                          onEdit();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          if (sprint.status == SprintStatus.planned)
                            const PopupMenuItem<String>(
                              value: 'start',
                              child: Text('Start sprint'),
                            ),
                          if (sprint.status == SprintStatus.active)
                            const PopupMenuItem<String>(
                              value: 'complete',
                              child: Text('Complete sprint'),
                            ),
                          const PopupMenuItem<String>(
                            value: 'retro',
                            child: Text('Retrospective'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sprint.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sprint.startDate != null ||
                  sprint.endDate != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _range(sprint),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text(
                    '${sprint.donePoints}/${sprint.totalPoints} pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (sprint.status == SprintStatus.active && days != null)
                    Text(
                      days < 0
                          ? '${-days}d over'
                          : (days == 0 ? 'Due today' : '${days}d left'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: days < 0
                            ? AppColors.rose
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sprint.pointsProgress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: sprint.status.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${sprint.doneCount}/${sprint.taskCount} tasks done',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _range(Sprint s) {
    final String a = s.startDate == null
        ? '—'
        : shortDate(s.startDate!.toLocal());
    final String b = s.endDate == null ? '—' : shortDate(s.endDate!.toLocal());
    return '$a  →  $b';
  }
}

/// The strip above the selected sprint's board: name, goal and a points bar.
class _SprintBoardHeader extends StatelessWidget {
  const _SprintBoardHeader({required this.sprint});
  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  sprint.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: sprint.status.label,
                color: sprint.status.color,
              ),
            ],
          ),
          if (sprint.goal.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(sprint.goal, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                '${sprint.donePoints}/${sprint.totalPoints} points',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${(sprint.pointsProgress * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: sprint.pointsProgress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// The backlog list: unsprinted top-level tasks, each addable to the selected
/// sprint.
class _Backlog extends StatelessWidget {
  const _Backlog({
    required this.tasks,
    required this.targetSprint,
    required this.onAdd,
    required this.onEdit,
  });

  final List<Task> tasks;
  final Sprint? targetSprint;
  final void Function(Task task, int sprintId) onAdd;
  final void Function(Task task) onEdit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nothing in the backlog.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final Task t in tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onEdit(t),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: t.points > 0
                ? Text(
                    '${t.points} pts',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                : null,
            trailing:
                (targetSprint != null &&
                    targetSprint!.status != SprintStatus.completed)
                ? TextButton.icon(
                    onPressed: () => onAdd(t, targetSprint!.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('To sprint'),
                  )
                : null,
          ),
      ],
    );
  }
}
