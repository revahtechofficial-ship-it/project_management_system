import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/task_priority.dart';
import '../../../data/models/automation_rule.dart';
import '../../../data/models/project.dart';
import '../../../data/models/sprint.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/workflow_status.dart';
import '../../projects/providers/projects_providers.dart';
import '../../sprints/providers/sprints_providers.dart';
import '../../tasks/providers/statuses_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/automations_providers.dart';

const List<(String, String)> kTriggers = <(String, String)>[
  ('task_created', 'When a task is created'),
  ('status_changed', 'When the status changes'),
  ('task_completed', 'When a task is completed'),
  ('assignee_changed', 'When the assignee changes'),
];

const List<(String, String)> kFields = <(String, String)>[
  ('status', 'Status'),
  ('priority', 'Priority'),
  ('project', 'Project'),
  ('sprint', 'Sprint'),
  ('assignee', 'Assignee'),
  ('has_assignee', 'Has assignee'),
  ('has_due', 'Has due date'),
  ('is_overdue', 'Is overdue'),
];

const List<(String, String)> kOps = <(String, String)>[
  ('is', 'is'),
  ('is_not', 'is not'),
];

const List<(String, String)> kActions = <(String, String)>[
  ('set_status', 'Set status to'),
  ('set_priority', 'Set priority to'),
  ('assign', 'Assign to'),
  ('reassign', 'Reassign to'),
  ('unassign', 'Clear assignees'),
  ('add_tag', 'Add tag'),
  ('set_due_in_days', 'Set due date in N days'),
  ('move_to_sprint', 'Move to sprint'),
  ('clear_sprint', 'Remove from sprint'),
  ('notify_assignee', 'Notify the assignee'),
  ('notify_user', 'Notify a person'),
];

String condKind(String field) => switch (field) {
  'status' => 'status',
  'priority' => 'priority',
  'project' => 'project',
  'sprint' => 'sprint',
  'assignee' => 'user',
  'has_assignee' || 'has_due' || 'is_overdue' => 'yesno',
  _ => 'text',
};

String actKind(String type) => switch (type) {
  'set_status' => 'status',
  'set_priority' => 'priority',
  'assign' || 'reassign' || 'notify_user' => 'user',
  'add_tag' => 'text',
  'set_due_in_days' => 'number',
  'move_to_sprint' => 'sprint',
  _ => 'none',
};

/// Opens the create/edit automation builder. Returns true if saved.
Future<bool?> showAutomationBuilder(
  BuildContext context, {
  AutomationRule? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _AutomationBuilder(existing: existing),
  );
}

class _AutomationBuilder extends ConsumerStatefulWidget {
  const _AutomationBuilder({this.existing});

  final AutomationRule? existing;

  @override
  ConsumerState<_AutomationBuilder> createState() => _AutomationBuilderState();
}

class _AutomationBuilderState extends ConsumerState<_AutomationBuilder> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _trigger = widget.existing?.trigger ?? 'task_created';
  late final List<RuleCondition> _conditions = <RuleCondition>[
    ...?widget.existing?.conditions,
  ];
  late final List<RuleAction> _actions = <RuleAction>[
    ...?widget.existing?.actions,
  ];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A name is required');
      return;
    }
    if (_actions.isEmpty) {
      setState(() => _error = 'Add at least one action');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(automationsRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: _name.text.trim(),
          enabled: widget.existing!.enabled,
          trigger: _trigger,
          conditions: _conditions,
          actions: _actions,
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          enabled: true,
          trigger: _trigger,
          conditions: _conditions,
          actions: _actions,
        );
      }
      ref.invalidate(automationsProvider);
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit automation' : 'New automation'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              const _Label('When'),
              _KeyDropdown(
                value: _trigger,
                options: kTriggers,
                onChanged: (String v) => setState(() => _trigger = v),
              ),
              const SizedBox(height: 16),
              const _Label('If all of these (optional)'),
              for (int i = 0; i < _conditions.length; i++)
                _ConditionRow(
                  condition: _conditions[i],
                  onChanged: (RuleCondition c) =>
                      setState(() => _conditions[i] = c),
                  onRemove: () => setState(() => _conditions.removeAt(i)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _conditions.add(const RuleCondition())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add condition'),
                ),
              ),
              const SizedBox(height: 8),
              const _Label('Then do'),
              for (int i = 0; i < _actions.length; i++)
                _ActionRow(
                  action: _actions[i],
                  onChanged: (RuleAction a) => setState(() => _actions[i] = a),
                  onRemove: () => setState(() => _actions.removeAt(i)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _actions.add(const RuleAction())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add action'),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.condition,
    required this.onChanged,
    required this.onRemove,
  });

  final RuleCondition condition;
  final ValueChanged<RuleCondition> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _KeyDropdown(
              value: condition.field,
              options: kFields,
              onChanged: (String v) =>
                  onChanged(condition.copyWith(field: v, value: '')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _KeyDropdown(
              value: condition.op,
              options: kOps,
              onChanged: (String v) => onChanged(condition.copyWith(op: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _ValueEditor(
              kind: condKind(condition.field),
              value: condition.value,
              onChanged: (String v) => onChanged(condition.copyWith(value: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.onChanged,
    required this.onRemove,
  });

  final RuleAction action;
  final ValueChanged<RuleAction> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String kind = actKind(action.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _KeyDropdown(
              value: action.type,
              options: kActions,
              onChanged: (String v) =>
                  onChanged(action.copyWith(type: v, value: '')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: kind == 'none'
                ? const SizedBox.shrink()
                : _ValueEditor(
                    kind: kind,
                    value: action.value,
                    onChanged: (String v) =>
                        onChanged(action.copyWith(value: v)),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A dropdown over (key, label) options.
class _KeyDropdown extends StatelessWidget {
  const _KeyDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool has = options.any(((String, String) o) => o.$1 == value);
    return DropdownButtonFormField<String>(
      initialValue: has ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: <DropdownMenuItem<String>>[
        for (final (String, String) o in options)
          DropdownMenuItem<String>(
            value: o.$1,
            child: Text(o.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (String? v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }
}

/// Renders the right value input for a condition/action value kind.
class _ValueEditor extends ConsumerWidget {
  const _ValueEditor({
    required this.kind,
    required this.value,
    required this.onChanged,
  });

  final String kind;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (kind) {
      case 'status':
        final List<WorkflowStatus> statuses =
            ref.watch(statusesProvider).asData?.value ??
            WorkflowStatus.defaults;
        return _KeyDropdown(
          value: value,
          options: <(String, String)>[
            for (final WorkflowStatus s in statuses) (s.key, s.label),
          ],
          onChanged: onChanged,
        );
      case 'priority':
        return _KeyDropdown(
          value: value,
          options: <(String, String)>[
            for (final TaskPriority p in TaskPriority.values)
              (p.toJson(), p.label),
          ],
          onChanged: onChanged,
        );
      case 'project':
        final List<Project> projects =
            ref.watch(projectsProvider).asData?.value ?? const <Project>[];
        return _KeyDropdown(
          value: value,
          options: <(String, String)>[
            for (final Project p in projects) ('${p.id}', p.name),
          ],
          onChanged: onChanged,
        );
      case 'sprint':
        final List<Sprint> sprints =
            ref.watch(sprintsProvider).asData?.value ?? const <Sprint>[];
        return _KeyDropdown(
          value: value,
          options: <(String, String)>[
            for (final Sprint s in sprints) ('${s.id}', s.name),
          ],
          onChanged: onChanged,
        );
      case 'user':
        final List<TeamMember> team =
            ref.watch(teamMembersProvider).asData?.value ??
            const <TeamMember>[];
        return _KeyDropdown(
          value: value,
          options: <(String, String)>[
            for (final TeamMember m in team)
              ('${m.id}', m.name.isEmpty ? m.email : m.name),
          ],
          onChanged: onChanged,
        );
      case 'yesno':
        return _KeyDropdown(
          value: value,
          options: const <(String, String)>[('yes', 'Yes'), ('no', 'No')],
          onChanged: onChanged,
        );
      case 'number':
        return _TextValue(
          value: value,
          hint: 'Days',
          number: true,
          onChanged: onChanged,
        );
      default:
        return _TextValue(value: value, hint: 'Value', onChanged: onChanged);
    }
  }
}

class _TextValue extends StatefulWidget {
  const _TextValue({
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.number = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool number;

  @override
  State<_TextValue> createState() => _TextValueState();
}

class _TextValueState extends State<_TextValue> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: widget.number ? TextInputType.number : null,
      inputFormatters: widget.number
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(isDense: true, hintText: widget.hint),
      onChanged: widget.onChanged,
    );
  }
}
