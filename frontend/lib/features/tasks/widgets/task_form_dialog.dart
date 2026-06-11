import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/enums/dependency_type.dart';
import '../../../data/enums/recurrence_type.dart';
import '../../../data/enums/task_status.dart';
import '../../../data/models/checklist_item.dart';
import '../../../data/models/project.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_dependency.dart';
import '../../../data/models/team_member.dart';
import '../../projects/providers/projects_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/dependencies_providers.dart';
import '../providers/subtask_providers.dart';
import '../providers/tasks_providers.dart';

/// Create/edit dialog for a task, with project, assignee and schedule pickers
/// fed by the live providers. Pops `true` on a successful save.
class TaskFormDialog extends ConsumerStatefulWidget {
  const TaskFormDialog({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  int? _projectId;
  int? _assigneeId;
  DateTime? _start;
  DateTime? _due;
  TaskStatus _status = TaskStatus.todo;
  RecurrenceType _recurrence = RecurrenceType.none;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final Task? t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _projectId = t?.projectId;
    _assigneeId = t?.assigneeId;
    _start = t?.startDate;
    _due = t?.dueDate;
    _status = t == null || t.status == TaskStatus.other
        ? TaskStatus.todo
        : t.status;
    _recurrence = t == null || t.recurrence == RecurrenceType.other
        ? RecurrenceType.none
        : t.recurrence;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_start != null && _due != null && _due!.isBefore(_start!)) {
      setState(() => _error = 'Due date cannot be before the start date');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tasksRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.task!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          projectId: _projectId,
          assigneeId: _assigneeId,
          startDate: _start,
          dueDate: _due,
          status: _status,
          recurrence: _recurrence,
        );
      } else {
        await repo.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          projectId: _projectId,
          assigneeId: _assigneeId,
          startDate: _start,
          dueDate: _due,
          status: _status,
          recurrence: _recurrence,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _pick(bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (isStart ? _start : _due) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _due = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];

    return AlertDialog(
      title: Text(_isEdit ? 'Edit task' : 'New task'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: <DropdownMenuItem<TaskStatus>>[
                    for (final TaskStatus s in TaskStatus.board)
                      DropdownMenuItem<TaskStatus>(
                        value: s,
                        child: Text(s.label),
                      ),
                  ],
                  onChanged: (TaskStatus? v) =>
                      setState(() => _status = v ?? TaskStatus.todo),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RecurrenceType>(
                  initialValue: _recurrence,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.repeat, size: 20),
                  ),
                  items: <DropdownMenuItem<RecurrenceType>>[
                    for (final RecurrenceType rec
                        in RecurrenceType.selectableValues)
                      DropdownMenuItem<RecurrenceType>(
                        value: rec,
                        child: Text(rec.label),
                      ),
                  ],
                  onChanged: (RecurrenceType? v) =>
                      setState(() => _recurrence = v ?? RecurrenceType.none),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('No project')),
                    for (final Project p in projects)
                      DropdownMenuItem<int?>(
                          value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (int? v) => setState(() => _projectId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _assigneeId,
                  decoration: const InputDecoration(labelText: 'Assignee'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Unassigned')),
                    for (final TeamMember m in members)
                      DropdownMenuItem<int?>(
                          value: m.id,
                          child:
                              Text(m.name.isEmpty ? m.email : m.name)),
                  ],
                  onChanged: (int? v) => setState(() => _assigneeId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _DateField(
                        label: 'Start',
                        value: _start,
                        onTap: () => _pick(true),
                        onClear: () => setState(() => _start = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Due',
                        value: _due,
                        onTap: () => _pick(false),
                        onClear: () => setState(() => _due = null),
                      ),
                    ),
                  ],
                ),
                if (_isEdit) ...<Widget>[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: Column(
                      children: <Widget>[
                        _Expander(
                          title: 'Subtasks',
                          child: _SubtaskSection(taskId: widget.task!.id),
                        ),
                        _Expander(
                          title: 'Checklist',
                          child: _ChecklistSection(taskId: widget.task!.id),
                        ),
                        _Expander(
                          title: 'Dependencies',
                          child:
                              _DependencySection(taskId: widget.task!.id),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!,
                        style: TextStyle(color: scheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event, size: 20)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? 'None' : shortDate(value!)),
      ),
    );
  }
}

/// Lists and edits the tasks this task depends on. Adding/removing a link hits
/// the API immediately (the backend reschedules), then refreshes tasks + deps.
class _DependencySection extends ConsumerStatefulWidget {
  const _DependencySection({required this.taskId});
  final int taskId;

  @override
  ConsumerState<_DependencySection> createState() =>
      _DependencySectionState();
}

class _DependencySectionState extends ConsumerState<_DependencySection> {
  int? _predId;
  DependencyType _type = DependencyType.finishToStart;
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    final int? pred = _predId;
    if (pred == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dependenciesRepositoryProvider).create(
            predecessorId: pred,
            successorId: widget.taskId,
            type: _type,
          );
      ref.invalidate(dependenciesProvider);
      ref.invalidate(tasksProvider);
      setState(() {
        _busy = false;
        _predId = null;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _messageFor(e);
      });
    }
  }

  Future<void> _remove(int id) async {
    await ref.read(dependenciesRepositoryProvider).delete(id);
    ref.invalidate(dependenciesProvider);
    ref.invalidate(tasksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TaskDependency> deps =
        ref.watch(dependenciesProvider).asData?.value ??
            const <TaskDependency>[];
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final Map<int, String> titleById = <int, String>{
      for (final Task t in tasks) t.id: t.title,
    };
    final List<TaskDependency> preds = deps
        .where((TaskDependency d) => d.successorId == widget.taskId)
        .toList();
    final Set<int> predIds =
        preds.map((TaskDependency d) => d.predecessorId).toSet();
    final List<Task> candidates = tasks
        .where((Task t) => t.id != widget.taskId && !predIds.contains(t.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Depends on',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        if (preds.isEmpty)
          Text('Nothing yet',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant))
        else
          for (final TaskDependency d in preds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${titleById[d.predecessorId] ?? 'Task ${d.predecessorId}'}  ·  ${d.type.shortLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _remove(d.id),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: _predId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Add predecessor',
                  isDense: true,
                ),
                items: <DropdownMenuItem<int?>>[
                  for (final Task t in candidates)
                    DropdownMenuItem<int?>(
                      value: t.id,
                      child: Text(t.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (int? v) => setState(() => _predId = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 86,
              child: DropdownButtonFormField<DependencyType>(
                initialValue: _type,
                isDense: true,
                decoration: const InputDecoration(isDense: true),
                items: <DropdownMenuItem<DependencyType>>[
                  for (final DependencyType t
                      in DependencyType.selectableValues)
                    DropdownMenuItem<DependencyType>(
                      value: t,
                      child: Text(t.shortLabel),
                    ),
                ],
                onChanged: (DependencyType? v) =>
                    setState(() => _type = v ?? DependencyType.finishToStart),
              ),
            ),
            IconButton(
              tooltip: 'Add dependency',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              onPressed: (_predId == null || _busy) ? null : _add,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!,
                style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
      ],
    );
  }
}

String _messageFor(Object e) {
  if (e is DioException) {
    final dynamic data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
  }
  return 'Could not add dependency';
}

/// A compact, collapsible section used inside the task dialog.
class _Expander extends StatelessWidget {
  const _Expander({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      children: <Widget>[child],
    );
  }
}

/// Manages a task's subtasks: quick-add, toggle done, delete. Persists
/// immediately and refreshes the parent's rollup counts.
class _SubtaskSection extends ConsumerStatefulWidget {
  const _SubtaskSection({required this.taskId});
  final int taskId;

  @override
  ConsumerState<_SubtaskSection> createState() => _SubtaskSectionState();
}

class _SubtaskSectionState extends ConsumerState<_SubtaskSection> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(subtasksProvider(widget.taskId));
    ref.invalidate(tasksProvider);
  }

  Future<void> _add() async {
    final String title = _input.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(tasksRepositoryProvider)
        .create(title: title, parentId: widget.taskId);
    _input.clear();
    setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> subs =
        ref.watch(subtasksProvider(widget.taskId)).asData?.value ??
            const <Task>[];
    final int done = subs.where((Task t) => t.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (subs.isNotEmpty)
          Text('$done of ${subs.length} complete',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
        for (final Task sub in subs)
          Row(
            children: <Widget>[
              SizedBox(
                width: 30,
                height: 30,
                child: Checkbox(
                  value: sub.done,
                  onChanged: (bool? v) async {
                    await ref
                        .read(tasksRepositoryProvider)
                        .setDone(sub.id, done: v ?? false);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(sub.title,
                    style: TextStyle(
                        decoration:
                            sub.done ? TextDecoration.lineThrough : null,
                        color: sub.done ? scheme.onSurfaceVariant : null)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () async {
                  await ref.read(tasksRepositoryProvider).delete(sub.id);
                  _refresh();
                },
              ),
            ],
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                decoration: const InputDecoration(
                  hintText: 'Add a subtask',
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// Manages a task's checklist: add, toggle, delete, with a progress bar.
class _ChecklistSection extends ConsumerStatefulWidget {
  const _ChecklistSection({required this.taskId});
  final int taskId;

  @override
  ConsumerState<_ChecklistSection> createState() =>
      _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<_ChecklistSection> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(checklistProvider(widget.taskId));

  Future<void> _add() async {
    final String content = _input.text.trim();
    if (content.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(checklistRepositoryProvider)
        .add(widget.taskId, content);
    _input.clear();
    setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ChecklistItem> items =
        ref.watch(checklistProvider(widget.taskId)).asData?.value ??
            const <ChecklistItem>[];
    final int done = items.where((ChecklistItem i) => i.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (items.isNotEmpty) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: items.isEmpty ? 0 : done / items.length,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final ChecklistItem item in items)
          Row(
            children: <Widget>[
              SizedBox(
                width: 30,
                height: 30,
                child: Checkbox(
                  value: item.done,
                  onChanged: (bool? v) async {
                    await ref
                        .read(checklistRepositoryProvider)
                        .setDone(item.id, v ?? false);
                    _refresh();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item.content,
                    style: TextStyle(
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                        color:
                            item.done ? scheme.onSurfaceVariant : null)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () async {
                  await ref
                      .read(checklistRepositoryProvider)
                      .delete(item.id);
                  _refresh();
                },
              ),
            ],
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                decoration: const InputDecoration(
                  hintText: 'Add a checklist item',
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}
