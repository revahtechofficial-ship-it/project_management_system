import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../reminders/widgets/reminder_dialog.dart';
import '../../releases/providers/releases_providers.dart';
import '../../../data/enums/dependency_type.dart';
import '../../../data/enums/issue_type.dart';
import '../../../data/enums/recurrence_type.dart';
import '../../../data/enums/task_priority.dart';
import '../../../data/enums/task_severity.dart';
import '../../../data/models/release.dart';
import '../../../data/models/checklist_item.dart';
import '../../../data/models/project.dart';
import '../../../data/models/sprint.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_dependency.dart';
import '../../../data/models/task_template.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/workflow_status.dart';
import '../../projects/providers/projects_providers.dart';
import '../../sprints/providers/sprints_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/dependencies_providers.dart';
import '../providers/statuses_providers.dart';
import '../providers/subtask_providers.dart';
import '../providers/task_templates_providers.dart';
import '../providers/tasks_providers.dart';
import 'task_attachments.dart';
import 'task_comments.dart';
import 'task_custom_fields.dart';

/// Create/edit dialog for a task, with project, assignee and schedule pickers
/// fed by the live providers. Pops `true` on a successful save.
class TaskFormDialog extends ConsumerStatefulWidget {
  const TaskFormDialog({super.key, this.task, this.template});

  final Task? task;

  /// When creating (task == null), pre-fills the form from this template.
  final TaskTemplate? template;

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  int? _projectId;
  late List<int> _assigneeIds;
  DateTime? _start;
  DateTime? _due;
  late String _statusKey;
  RecurrenceType _recurrence = RecurrenceType.none;
  TaskPriority _priority = TaskPriority.none;
  final TextEditingController _tagInput = TextEditingController();
  late List<String> _tags;
  late final TextEditingController _estimate;
  late final TextEditingController _points;
  int? _sprintId;
  IssueType _issueType = IssueType.task;
  TaskSeverity _severity = TaskSeverity.none;
  int? _releaseId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final Task? t = widget.task;
    final TaskTemplate? tmpl = widget.template;
    _title = TextEditingController(text: t?.title ?? tmpl?.title ?? '');
    _description = TextEditingController(
      text: t?.description ?? tmpl?.description ?? '',
    );
    _projectId = t?.projectId ?? tmpl?.projectId;
    _assigneeIds = List<int>.of(
      t?.assigneeIds ??
          (t?.assigneeId != null ? <int>[t!.assigneeId!] : const <int>[]),
    );
    _start = t?.startDate;
    _due = t?.dueDate;
    _statusKey = t?.statusKey ?? tmpl?.statusKey ?? 'todo';
    _recurrence = t != null
        ? (t.recurrence == RecurrenceType.other
              ? RecurrenceType.none
              : t.recurrence)
        : (tmpl?.recurrence ?? RecurrenceType.none);
    _priority = t?.priority ?? tmpl?.priority ?? TaskPriority.none;
    _tags = List<String>.of(t?.tags ?? tmpl?.tags ?? const <String>[]);
    final int est = t?.estimateMinutes ?? tmpl?.estimateMinutes ?? 0;
    _estimate = TextEditingController(text: est > 0 ? _hoursLabel(est) : '');
    _sprintId = t?.sprintId;
    final int pts = t?.points ?? 0;
    _points = TextEditingController(text: pts > 0 ? '$pts' : '');
    _issueType = t?.issueType ?? IssueType.task;
    _severity = t?.severity ?? TaskSeverity.none;
    _releaseId = t?.releaseId;
  }

  /// Parses the story-points field (0 when blank/invalid).
  int _pointsValue() {
    final int? p = int.tryParse(_points.text.trim());
    return (p == null || p < 0) ? 0 : p;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tagInput.dispose();
    _estimate.dispose();
    _points.dispose();
    super.dispose();
  }

  /// Minutes → an editable hours string (e.g. 90 → "1.5", 60 → "1").
  String _hoursLabel(int minutes) {
    final double h = minutes / 60.0;
    return h == h.roundToDouble() ? h.toInt().toString() : '$h';
  }

  /// Parses the hours field back into whole minutes (0 when blank/invalid).
  int _estimateMinutes() {
    final double? hours = double.tryParse(_estimate.text.trim());
    if (hours == null || hours <= 0) {
      return 0;
    }
    return (hours * 60).round();
  }

  /// Display name for a member id (falls back to email, then a placeholder).
  String _assigneeName(List<TeamMember> members, int id) {
    for (final TeamMember m in members) {
      if (m.id == id) {
        return m.name.isEmpty ? m.email : m.name;
      }
    }
    return 'User $id';
  }

  void _addTag(String raw) {
    final String tag = raw.trim();
    if (tag.isEmpty ||
        _tags.any((String t) => t.toLowerCase() == tag.toLowerCase())) {
      _tagInput.clear();
      return;
    }
    setState(() => _tags.add(tag));
    _tagInput.clear();
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
          assigneeIds: _assigneeIds,
          startDate: _start,
          dueDate: _due,
          statusKey: _statusKey,
          recurrence: _recurrence,
          priority: _priority,
          tags: _tags,
          estimateMinutes: _estimateMinutes(),
          points: _pointsValue(),
          sprintId: _sprintId,
          issueType: _issueType,
          severity: _severity,
          releaseId: _releaseId,
        );
      } else {
        await repo.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          projectId: _projectId,
          assigneeIds: _assigneeIds,
          startDate: _start,
          dueDate: _due,
          statusKey: _statusKey,
          recurrence: _recurrence,
          priority: _priority,
          tags: _tags,
          estimateMinutes: _estimateMinutes(),
          points: _pointsValue(),
          sprintId: _sprintId,
          issueType: _issueType,
          severity: _severity,
          releaseId: _releaseId,
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

  /// Saves the current field values as a reusable named template.
  Future<void> _saveAsTemplate() async {
    final TextEditingController nameCtrl = TextEditingController(
      text: _title.text.trim(),
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
          onSubmitted: (String v) => Navigator.pop(context, v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    try {
      await ref
          .read(taskTemplatesRepositoryProvider)
          .create(
            name: name,
            title: _title.text.trim(),
            description: _description.text.trim(),
            statusKey: _statusKey,
            priority: _priority,
            recurrence: _recurrence,
            estimateMinutes: _estimateMinutes(),
            tags: _tags,
            projectId: _projectId,
          );
      ref.invalidate(taskTemplatesProvider);
      if (mounted) {
        context.showSuccess('Saved template "$name"');
      }
    } catch (_) {
      if (mounted) {
        context.showError('Could not save template');
      }
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
    final List<WorkflowStatus> loadedStatuses =
        ref.watch(statusesProvider).asData?.value ?? const <WorkflowStatus>[];
    final List<WorkflowStatus> statuses = loadedStatuses.isEmpty
        ? WorkflowStatus.defaults
        : loadedStatuses;
    final List<Sprint> sprints =
        ref.watch(sprintsProvider).asData?.value ?? const <Sprint>[];

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(_isEdit ? 'Edit task' : 'New task')),
          if (_isEdit) ...<Widget>[
            IconButton(
              tooltip: 'Set a reminder',
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              onPressed: () => showReminderDialog(
                context,
                taskId: widget.task!.id,
                taskTitle: widget.task!.title,
              ),
            ),
            FavoriteButton(
              kind: 'task',
              itemId: widget.task!.id,
              label: widget.task!.title,
              route: '/tasks',
            ),
          ],
        ],
      ),
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
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                if (statuses.isEmpty)
                  const InputDecorator(
                    decoration: InputDecoration(labelText: 'Status'),
                    child: Text('Loading…'),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue:
                        statuses.any((WorkflowStatus s) => s.key == _statusKey)
                        ? _statusKey
                        : statuses.first.key,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: <DropdownMenuItem<String>>[
                      for (final WorkflowStatus s in statuses)
                        DropdownMenuItem<String>(
                          value: s.key,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _statusKey = v ?? _statusKey),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: <DropdownMenuItem<TaskPriority>>[
                    for (final TaskPriority p in TaskPriority.values)
                      DropdownMenuItem<TaskPriority>(
                        value: p,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              p.isSet
                                  ? Icons.flag_rounded
                                  : Icons.outlined_flag,
                              size: 16,
                              color: p.color,
                            ),
                            const SizedBox(width: 8),
                            Text(p.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (TaskPriority? v) =>
                      setState(() => _priority = v ?? TaskPriority.none),
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
                  initialValue: sprints.any((Sprint s) => s.id == _sprintId)
                      ? _sprintId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Sprint',
                    prefixIcon: Icon(Icons.directions_run, size: 20),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Backlog (no sprint)'),
                    ),
                    for (final Sprint s in sprints)
                      DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (int? v) => setState(() => _sprintId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No project'),
                    ),
                    for (final Project p in projects)
                      DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (int? v) => setState(() => _projectId = v),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assignees',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_assigneeIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final int id in _assigneeIds)
                          _PersonChip(
                            label: _assigneeName(members, id),
                            onRemove: () =>
                                setState(() => _assigneeIds.remove(id)),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<int>(
                    tooltip: 'Add assignee',
                    enabled: members.any(
                      (TeamMember m) => !_assigneeIds.contains(m.id),
                    ),
                    onSelected: (int id) =>
                        setState(() => _assigneeIds.add(id)),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<int>>[
                          for (final TeamMember m in members.where(
                            (TeamMember m) => !_assigneeIds.contains(m.id),
                          ))
                            PopupMenuItem<int>(
                              value: m.id,
                              child: Text(m.name.isEmpty ? m.email : m.name),
                            ),
                        ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.person_add_alt,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _assigneeIds.isEmpty
                                ? 'Add assignee'
                                : 'Add another',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<IssueType>(
                        initialValue: _issueType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(
                            _issueType.icon,
                            size: 20,
                            color: _issueType.color,
                          ),
                        ),
                        items: <DropdownMenuItem<IssueType>>[
                          for (final IssueType t in IssueType.values)
                            DropdownMenuItem<IssueType>(
                              value: t,
                              child: Text(t.label),
                            ),
                        ],
                        onChanged: (IssueType? t) =>
                            setState(() => _issueType = t ?? IssueType.task),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReleaseField(
                        value: _releaseId,
                        onChanged: (int? id) =>
                            setState(() => _releaseId = id),
                      ),
                    ),
                  ],
                ),
                if (_issueType == IssueType.bug) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskSeverity>(
                    initialValue: _severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: <DropdownMenuItem<TaskSeverity>>[
                      for (final TaskSeverity s in TaskSeverity.values)
                        DropdownMenuItem<TaskSeverity>(
                          value: s,
                          child: Text(s.label),
                        ),
                    ],
                    onChanged: (TaskSeverity? s) =>
                        setState(() => _severity = s ?? TaskSeverity.none),
                  ),
                ],
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
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _estimate,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Estimate (hours)',
                          hintText: 'e.g. 1.5',
                          prefixIcon: Icon(Icons.timer_outlined, size: 20),
                        ),
                        validator: (String? v) {
                          final String s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return null;
                          }
                          final double? h = double.tryParse(s);
                          return (h == null || h < 0) ? 'Enter hours' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _points,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Points',
                          hintText: 'e.g. 5',
                          prefixIcon: Icon(Icons.bolt_outlined, size: 20),
                        ),
                        validator: (String? v) {
                          final String s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return null;
                          }
                          final int? p = int.tryParse(s);
                          return (p == null || p < 0) ? 'Whole number' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tags',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final String tag in _tags)
                          _TagChip(
                            tag: tag,
                            onRemove: () => setState(() => _tags.remove(tag)),
                          ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _tagInput,
                  decoration: const InputDecoration(
                    hintText: 'Add a tag and press enter',
                    isDense: true,
                    prefixIcon: Icon(Icons.sell_outlined, size: 18),
                  ),
                  onSubmitted: _addTag,
                ),
                if (_isEdit) ...<Widget>[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: Column(
                      children: <Widget>[
                        _Expander(
                          title: 'Comments',
                          child: TaskCommentsSection(taskId: widget.task!.id),
                        ),
                        _Expander(
                          title: 'Attachments',
                          child: TaskAttachmentsSection(
                            taskId: widget.task!.id,
                          ),
                        ),
                        _Expander(
                          title: 'Custom fields',
                          child: TaskCustomFieldsSection(
                            taskId: widget.task!.id,
                          ),
                        ),
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
                          child: _DependencySection(taskId: widget.task!.id),
                        ),
                        _Expander(
                          title: 'Activity',
                          child: TaskActivitySection(taskId: widget.task!.id),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        TextButton.icon(
          onPressed: _saving ? null : _saveAsTemplate,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('Save as template'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save' : 'Create'),
            ),
          ],
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

/// A dropdown that assigns the task to a release (or none).
class _ReleaseField extends ConsumerWidget {
  const _ReleaseField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Release> releases =
        ref.watch(releasesProvider).asData?.value ?? const <Release>[];
    final bool exists = value == null ||
        releases.any((Release r) => r.id == value);
    return DropdownButtonFormField<int?>(
      initialValue: exists ? value : null,
      decoration: const InputDecoration(
        labelText: 'Release',
        prefixIcon: Icon(Icons.rocket_launch_outlined, size: 20),
      ),
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(child: Text('None')),
        for (final Release r in releases)
          DropdownMenuItem<int?>(
            value: r.id,
            child: Text(
              r.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onRemove});
  final String tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Color color = avatarColor(tag);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            tag,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
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
  ConsumerState<_DependencySection> createState() => _DependencySectionState();
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
      await ref
          .read(dependenciesRepositoryProvider)
          .create(predecessorId: pred, successorId: widget.taskId, type: _type);
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
    // Include the project name so dependencies across projects are clear.
    String taskLabel(Task t) =>
        (t.projectName != null && t.projectName!.isNotEmpty)
        ? '${t.title}  ·  ${t.projectName}'
        : t.title;
    final Map<int, String> titleById = <int, String>{
      for (final Task t in tasks) t.id: taskLabel(t),
    };
    final List<TaskDependency> preds = deps
        .where((TaskDependency d) => d.successorId == widget.taskId)
        .toList();
    final Set<int> predIds = preds
        .map((TaskDependency d) => d.predecessorId)
        .toSet();
    final List<Task> candidates = tasks
        .where((Task t) => t.id != widget.taskId && !predIds.contains(t.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Depends on',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (preds.isEmpty)
          Text(
            'Nothing yet',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          )
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
                      child: Text(
                        taskLabel(t),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: (_predId == null || _busy) ? null : _add,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// A small chip showing an assignee (avatar + name) with a remove button.
class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          UserAvatar(name: label, radius: 10),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Icon(Icons.close, size: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
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
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: <Widget>[child],
    );
  }
}

/// Manages a task's subtasks as a nested tree: quick-add at the top, plus
/// per-row toggle/delete and inline add-subtask at any depth. Persists
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
          Text(
            '$done of ${subs.length} complete',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        for (final Task sub in subs)
          _SubtaskTile(task: sub, depth: 0, onChanged: _refresh),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// One subtask in the tree: a checkbox + title, a delete and (until the depth
/// cap) an inline "add subtask", and its own children rendered indented below.
class _SubtaskTile extends ConsumerStatefulWidget {
  const _SubtaskTile({
    required this.task,
    required this.depth,
    required this.onChanged,
  });

  final Task task;
  final int depth;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SubtaskTile> createState() => _SubtaskTileState();
}

class _SubtaskTileState extends ConsumerState<_SubtaskTile> {
  static const int _maxDepth = 5;
  final TextEditingController _input = TextEditingController();
  bool _adding = false;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool v) async {
    if (v && mounted) {
      celebrate(context);
    }
    await ref.read(tasksRepositoryProvider).setDone(widget.task.id, done: v);
    widget.onChanged();
  }

  Future<void> _delete() async {
    await ref.read(tasksRepositoryProvider).delete(widget.task.id);
    widget.onChanged();
  }

  Future<void> _addChild() async {
    final String title = _input.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(tasksRepositoryProvider)
        .create(title: title, parentId: widget.task.id);
    _input.clear();
    setState(() {
      _busy = false;
      _adding = false;
    });
    ref.invalidate(subtasksProvider(widget.task.id));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool canNest = widget.depth < _maxDepth;
    final List<Task> children = canNest
        ? (ref.watch(subtasksProvider(widget.task.id)).asData?.value ??
              const <Task>[])
        : const <Task>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 30,
              height: 30,
              child: Checkbox(
                value: widget.task.done,
                onChanged: (bool? v) => _toggle(v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: widget.task.done
                      ? TextDecoration.lineThrough
                      : null,
                  color: widget.task.done ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (canNest)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Add subtask',
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => setState(() => _adding = !_adding),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              onPressed: _delete,
            ),
          ],
        ),
        if (_adding)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addChild(),
                  ),
                ),
                IconButton(
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  onPressed: _busy ? null : _addChild,
                ),
              ],
            ),
          ),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Task child in children)
                  _SubtaskTile(
                    task: child,
                    depth: widget.depth + 1,
                    onChanged: () {
                      ref.invalidate(subtasksProvider(widget.task.id));
                      widget.onChanged();
                    },
                  ),
              ],
            ),
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
  ConsumerState<_ChecklistSection> createState() => _ChecklistSectionState();
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
    await ref.read(checklistRepositoryProvider).add(widget.taskId, content);
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
                child: Text(
                  item.content,
                  style: TextStyle(
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    color: item.done ? scheme.onSurfaceVariant : null,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () async {
                  await ref.read(checklistRepositoryProvider).delete(item.id);
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}
