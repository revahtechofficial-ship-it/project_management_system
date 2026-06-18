import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/task_priority.dart';
import '../../data/enums/task_view.dart';
import '../../data/models/task.dart';
import '../../data/models/workflow_status.dart';
import 'providers/statuses_providers.dart';
import 'providers/tasks_providers.dart';
import 'widgets/task_board_view.dart';
import 'widgets/task_calendar_view.dart';
import 'widgets/task_form_dialog.dart';
import 'widgets/task_gantt_view.dart';

/// Lists and manages tasks with switchable List / Calendar / Timeline views
/// (AGENTS.md §1 feature page). The selected view is ephemeral UI state.
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskView _view = TaskView.list;
  bool _selecting = false;
  final Set<int> _selected = <int>{};

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _selected.clear();
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (!_selected.add(id)) {
        _selected.remove(id);
      }
    });
  }

  Future<void> _runBulk(String action, {Object? value}) async {
    final List<int> ids = _selected.toList();
    if (ids.isEmpty) {
      return;
    }
    try {
      await ref
          .read(tasksRepositoryProvider)
          .bulk(ids: ids, action: action, value: value);
      ref.invalidate(tasksProvider);
      if (mounted) {
        setState(() {
          _selected.clear();
          _selecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bulk action failed: $e')));
      }
    }
  }

  Future<void> _bulkDelete() async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete tasks'),
            content: Text(
              'Delete ${_selected.length} selected task(s)? This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) {
      await _runBulk('delete');
    }
  }

  Future<void> _newTask() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const TaskFormDialog(),
    );
    if (saved ?? false) {
      ref.invalidate(tasksProvider);
    }
  }

  Future<void> _editTask(Task task) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => TaskFormDialog(task: task),
    );
    if (saved ?? false) {
      ref.invalidate(tasksProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Task>> tasks = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 12,
              children: <Widget>[
                const Text(
                  'Tasks',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    SegmentedButton<TaskView>(
                      segments: <ButtonSegment<TaskView>>[
                        for (final TaskView v in TaskView.values)
                          ButtonSegment<TaskView>(
                            value: v,
                            icon: Icon(v.icon, size: 18),
                            label: Text(v.label),
                          ),
                      ],
                      selected: <TaskView>{_view},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<TaskView> s) => setState(() {
                        _view = s.first;
                        if (_view != TaskView.list) {
                          _selecting = false;
                          _selected.clear();
                        }
                      }),
                    ),
                    if (_view == TaskView.list)
                      IconButton(
                        tooltip: _selecting ? 'Cancel selection' : 'Select',
                        isSelected: _selecting,
                        icon: const Icon(Icons.checklist_rtl),
                        onPressed: _toggleSelecting,
                      ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(tasksProvider),
                    ),
                    FilledButton.icon(
                      onPressed: _newTask,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New task'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tasks.when(
                data: (List<Task> items) => _body(items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Center(
                  child: Text(
                    'Failed to load tasks:\n$err',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (_selecting && _selected.isNotEmpty)
              _BulkBar(
                count: _selected.length,
                statuses:
                    ref.watch(statusesProvider).asData?.value ??
                    WorkflowStatus.defaults,
                onComplete: () => _runBulk('done', value: true),
                onStatus: (String key) => _runBulk('status', value: key),
                onPriority: (TaskPriority p) =>
                    _runBulk('priority', value: p.toJson()),
                onDelete: _bulkDelete,
                onClear: () => setState(_selected.clear),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Task> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_rounded,
        message: 'No tasks yet. Create your first one.',
      );
    }
    return switch (_view) {
      TaskView.list => ListView.separated(
        itemCount: items.length,
        separatorBuilder: (BuildContext context, int i) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int i) => _selecting
            ? _SelectableTaskTile(
                task: items[i],
                selected: _selected.contains(items[i].id),
                onChanged: () => _toggleSelected(items[i].id),
              )
            : _TaskTile(task: items[i], onEdit: () => _editTask(items[i])),
      ),
      TaskView.board => TaskBoardView(tasks: items, onTapTask: _editTask),
      TaskView.calendar => TaskCalendarView(tasks: items, onTapTask: _editTask),
      TaskView.gantt => TaskGanttView(tasks: items, onTapTask: _editTask),
    };
  }
}

/// A single task row with completion toggle, schedule/links and delete.
class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.onEdit});

  final Task task;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool overdue =
        !task.done &&
        task.dueDate != null &&
        task.dueDate!.toLocal().isBefore(DateTime.now());
    final List<WorkflowStatus> statuses =
        ref.watch(statusesProvider).asData?.value ?? const <WorkflowStatus>[];
    final WorkflowStatus ws = WorkflowStatus.forKey(statuses, task.statusKey);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onEdit,
      leading: Checkbox(
        value: task.done,
        onChanged: (bool? value) async {
          await ref
              .read(tasksRepositoryProvider)
              .setDone(task.id, done: value ?? false);
          ref.invalidate(tasksProvider);
        },
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? scheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            StatusPill(label: ws.label, color: ws.color),
            if (task.priority.isSet)
              _Chip(
                icon: Icons.flag_rounded,
                label: task.priority.label,
                color: task.priority.color,
              ),
            if (task.projectName != null)
              _Chip(
                icon: Icons.folder_outlined,
                label: task.projectName!,
                color: AppColors.brand,
              ),
            if (task.assigneeNames.isNotEmpty)
              _Chip(
                icon: Icons.person_outline,
                label: task.assigneeLabel,
                color: AppColors.teal,
              ),
            if (task.dueDate != null)
              _Chip(
                icon: Icons.event,
                label: 'Due ${shortDate(task.dueDate!.toLocal())}',
                color: overdue ? AppColors.rose : AppColors.slate,
              ),
            if (task.subtaskCount > 0)
              _Chip(
                icon: Icons.checklist_rounded,
                label: '${task.subtaskDoneCount}/${task.subtaskCount}',
                color: AppColors.violet,
              ),
            if (task.estimateLabel.isNotEmpty)
              _Chip(
                icon: Icons.timer_outlined,
                label: task.estimateLabel,
                color: AppColors.sky,
              ),
            if (task.recurrence.repeats)
              _Chip(
                icon: Icons.repeat,
                label: task.recurrence.label,
                color: AppColors.slate,
              ),
            for (final String tag in task.tags.take(4))
              StatusPill(label: tag, color: avatarColor(tag)),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
        onPressed: () async {
          await ref.read(tasksRepositoryProvider).delete(task.id);
          ref.invalidate(tasksProvider);
        },
      ),
    );
  }
}

/// A task row in bulk-selection mode: a checkbox plus a compact summary.
class _SelectableTaskTile extends StatelessWidget {
  const _SelectableTaskTile({
    required this.task,
    required this.selected,
    required this.onChanged,
  });

  final Task task;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onChanged,
      selected: selected,
      leading: Checkbox(value: selected, onChanged: (_) => onChanged()),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Wrap(
        spacing: 8,
        children: <Widget>[
          StatusPill(label: task.status.label, color: task.status.color),
          if (task.priority.isSet)
            _Chip(
              icon: Icons.flag_rounded,
              label: task.priority.label,
              color: task.priority.color,
            ),
          if (task.projectName != null)
            _Chip(
              icon: Icons.folder_outlined,
              label: task.projectName!,
              color: AppColors.brand,
            ),
        ],
      ),
    );
  }
}

/// The floating action bar shown when one or more tasks are selected.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.statuses,
    required this.onComplete,
    required this.onStatus,
    required this.onPriority,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final List<WorkflowStatus> statuses;
  final VoidCallback onComplete;
  final ValueChanged<String> onStatus;
  final ValueChanged<TaskPriority> onPriority;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$count selected',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onComplete,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Complete'),
              ),
              PopupMenuButton<String>(
                onSelected: onStatus,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  for (final WorkflowStatus s in statuses)
                    PopupMenuItem<String>(value: s.key, child: Text(s.label)),
                ],
                child: const _BulkChip(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                ),
              ),
              PopupMenuButton<TaskPriority>(
                onSelected: onPriority,
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<TaskPriority>>[
                      for (final TaskPriority p in TaskPriority.values)
                        PopupMenuItem<TaskPriority>(
                          value: p,
                          child: Text(p.label),
                        ),
                    ],
                child: const _BulkChip(
                  icon: Icons.priority_high,
                  label: 'Priority',
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: scheme.error, size: 18),
                label: Text('Delete', style: TextStyle(color: scheme.error)),
              ),
              IconButton(
                tooltip: 'Clear selection',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill used as the tappable child of the status/priority menus.
class _BulkChip extends StatelessWidget {
  const _BulkChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
