import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/enums/task_view.dart';
import '../../data/models/task.dart';
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
                const Text('Tasks',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
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
                      onSelectionChanged: (Set<TaskView> s) =>
                          setState(() => _view = s.first),
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object err, _) => Center(
                  child: Text('Failed to load tasks:\n$err',
                      textAlign: TextAlign.center),
                ),
              ),
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
          itemBuilder: (BuildContext context, int i) =>
              _TaskTile(task: items[i], onEdit: () => _editTask(items[i])),
        ),
      TaskView.board => TaskBoardView(tasks: items, onTapTask: _editTask),
      TaskView.calendar =>
        TaskCalendarView(tasks: items, onTapTask: _editTask),
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
    final bool overdue = !task.done &&
        task.dueDate != null &&
        task.dueDate!.toLocal().isBefore(DateTime.now());
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
            StatusPill(label: task.status.label, color: task.status.color),
            if (task.projectName != null)
              _Chip(
                  icon: Icons.folder_outlined,
                  label: task.projectName!,
                  color: AppColors.brand),
            if (task.assigneeName != null)
              _Chip(
                  icon: Icons.person_outline,
                  label: task.assigneeName!,
                  color: AppColors.teal),
            if (task.dueDate != null)
              _Chip(
                  icon: Icons.event,
                  label: 'Due ${shortDate(task.dueDate!.toLocal())}',
                  color: overdue ? AppColors.rose : AppColors.slate),
            if (task.subtaskCount > 0)
              _Chip(
                  icon: Icons.checklist_rounded,
                  label: '${task.subtaskDoneCount}/${task.subtaskCount}',
                  color: AppColors.violet),
            if (task.recurrence.repeats)
              _Chip(
                  icon: Icons.repeat,
                  label: task.recurrence.label,
                  color: AppColors.slate),
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
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
