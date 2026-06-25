import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/enums/form_field_type.dart';
import '../../../data/enums/task_priority.dart';
import '../../../data/models/form_field.dart' as model;
import '../../../data/models/form_response_entry.dart';
import '../../../data/models/form_task_config.dart';
import '../../../data/models/project.dart';
import '../../../data/models/workspace_page.dart';
import '../../projects/providers/projects_providers.dart';
import '../providers/pages_providers.dart';

enum _FormView { build, fill, responses }

/// The form builder + filler: managers define fields (Build) and read
/// submissions (Responses); anyone with access can Fill and submit. The field
/// definition lives in the page body as JSON (AGENTS.md §9).
class FormEditorScreen extends ConsumerStatefulWidget {
  const FormEditorScreen({super.key, required this.pageId});

  final int pageId;

  @override
  ConsumerState<FormEditorScreen> createState() => _FormEditorScreenState();
}

class _FormEditorScreenState extends ConsumerState<FormEditorScreen> {
  final TextEditingController _title = TextEditingController();
  List<model.FormField> _fields = <model.FormField>[];
  FormTaskConfig _taskConfig = const FormTaskConfig();
  WorkspacePage? _page;
  _FormView _view = _FormView.fill;
  bool _loading = true;
  bool _saving = false;
  int _seq = 0;

  // Fill-mode answer state.
  final Map<String, TextEditingController> _text =
      <String, TextEditingController>{};
  final Map<String, String?> _selects = <String, String?>{};
  final Map<String, bool> _checks = <String, bool>{};

  bool get _canManage => _page?.canManage ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final TextEditingController c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .get(widget.pageId);
      _title.text = page.title;
      _fields = _parse(page.body);
      _taskConfig = _parseTaskConfig(page.body);
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
          _view = page.canManage && _fields.isEmpty
              ? _FormView.build
              : _FormView.fill;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<model.FormField> _parse(String body) {
    if (body.trim().isEmpty) {
      return <model.FormField>[];
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      return <model.FormField>[
        for (final dynamic f in data['fields'] as List<dynamic>? ?? <dynamic>[])
          model.FormField.fromJson(f as Map<String, dynamic>),
      ];
    } catch (_) {
      return <model.FormField>[];
    }
  }

  FormTaskConfig _parseTaskConfig(String body) {
    if (body.trim().isEmpty) {
      return const FormTaskConfig();
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      final Object? ct = data['create_task'];
      if (ct is Map<String, dynamic>) {
        return FormTaskConfig.fromJson(ct);
      }
    } catch (_) {
      // Fall through to the default config below.
    }
    return const FormTaskConfig();
  }

  String _serialize() => jsonEncode(<String, dynamic>{
    'fields': <Map<String, dynamic>>[
      for (final model.FormField f in _fields) f.toJson(),
    ],
    'create_task': _taskConfig.toJson(),
  });

  void _setTaskConfig(FormTaskConfig config) {
    setState(() => _taskConfig = config);
    _saveDefinition(silent: true);
  }

  Future<void> _saveDefinition({bool silent = false}) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(pagesRepositoryProvider)
          .update(widget.pageId, title: _title.text.trim(), body: _serialize());
      if (mounted) {
        setState(() => _saving = false);
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Future<void> _editField([model.FormField? existing]) async {
    final model.FormField? result = await showDialog<model.FormField>(
      context: context,
      builder: (BuildContext context) =>
          _FieldDialog(field: existing, newId: () => 'f${_seq++}'),
    );
    if (result == null) {
      return;
    }
    setState(() {
      final int i = _fields.indexWhere(
        (model.FormField f) => f.id == result.id,
      );
      if (i >= 0) {
        _fields[i] = result;
      } else {
        _fields.add(result);
      }
    });
    await _saveDefinition(silent: true);
  }

  void _move(int i, int delta) {
    final int j = i + delta;
    if (j < 0 || j >= _fields.length) {
      return;
    }
    setState(() {
      final model.FormField f = _fields.removeAt(i);
      _fields.insert(j, f);
    });
    _saveDefinition(silent: true);
  }

  void _remove(model.FormField f) {
    setState(() => _fields.remove(f));
    _saveDefinition(silent: true);
  }

  TextEditingController _ctrl(String id) =>
      _text.putIfAbsent(id, () => TextEditingController());

  Future<void> _submit() async {
    final Map<String, dynamic> answers = <String, dynamic>{};
    for (final model.FormField f in _fields) {
      final dynamic value = switch (f.type) {
        FormFieldType.checkbox => _checks[f.id] ?? false,
        FormFieldType.select => _selects[f.id],
        _ => _ctrl(f.id).text.trim(),
      };
      if (f.required) {
        final bool missing = switch (f.type) {
          FormFieldType.checkbox => value != true,
          FormFieldType.select => value == null || (value as String).isEmpty,
          _ => (value as String).isEmpty,
        };
        if (missing) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('"${f.label}" is required')));
          return;
        }
      }
      answers[f.label.isEmpty ? f.id : f.label] = value;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(pagesRepositoryProvider)
          .submitForm(widget.pageId, answers);
      if (mounted) {
        setState(() {
          _saving = false;
          for (final TextEditingController c in _text.values) {
            c.clear();
          }
          _selects.clear();
          _checks.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response submitted. Thank you!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? const Text('Form')
            : TextField(
                controller: _title,
                readOnly: !_canManage,
                onChanged: (_) {},
                onEditingComplete: _canManage
                    ? () => _saveDefinition(silent: true)
                    : null,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Untitled form',
                ),
              ),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: <Widget>[
                    if (_canManage)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: SegmentedButton<_FormView>(
                          segments: const <ButtonSegment<_FormView>>[
                            ButtonSegment<_FormView>(
                              value: _FormView.build,
                              icon: Icon(Icons.build_outlined, size: 18),
                              label: Text('Build'),
                            ),
                            ButtonSegment<_FormView>(
                              value: _FormView.fill,
                              icon: Icon(Icons.edit_note, size: 18),
                              label: Text('Fill'),
                            ),
                            ButtonSegment<_FormView>(
                              value: _FormView.responses,
                              icon: Icon(Icons.inbox_outlined, size: 18),
                              label: Text('Responses'),
                            ),
                          ],
                          selected: <_FormView>{_view},
                          showSelectedIcon: false,
                          onSelectionChanged: (Set<_FormView> s) =>
                              setState(() => _view = s.first),
                        ),
                      ),
                    Expanded(child: _content()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _content() {
    return switch (_view) {
      _FormView.build => _BuildView(
        fields: _fields,
        taskConfig: _taskConfig,
        onTaskConfigChanged: _setTaskConfig,
        onAdd: () => _editField(),
        onEdit: _editField,
        onRemove: _remove,
        onMove: _move,
      ),
      _FormView.fill =>
        _fields.isEmpty
            ? const Center(child: Text('This form has no fields yet.'))
            : _FillView(
                fields: _fields,
                controllerFor: _ctrl,
                selects: _selects,
                checks: _checks,
                onChanged: () => setState(() {}),
                onSubmit: _saving ? null : _submit,
              ),
      _FormView.responses => _ResponsesView(pageId: widget.pageId),
    };
  }
}

// --- Build view ------------------------------------------------------------

class _BuildView extends StatelessWidget {
  const _BuildView({
    required this.fields,
    required this.taskConfig,
    required this.onTaskConfigChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onMove,
  });

  final List<model.FormField> fields;
  final FormTaskConfig taskConfig;
  final ValueChanged<FormTaskConfig> onTaskConfigChanged;
  final VoidCallback onAdd;
  final ValueChanged<model.FormField> onEdit;
  final ValueChanged<model.FormField> onRemove;
  final void Function(int index, int delta) onMove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        for (int i = 0; i < fields.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(
                fields[i].label.isEmpty ? 'Untitled field' : fields[i].label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${fields[i].type.label}${fields[i].required ? ' · required' : ''}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              onTap: () => onEdit(fields[i]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: i == 0 ? null : () => onMove(i, -1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: i == fields.length - 1
                        ? null
                        : () => onMove(i, 1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppColors.rose,
                    onPressed: () => onRemove(fields[i]),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add field'),
        ),
        const SizedBox(height: 24),
        _TaskSettingsCard(
          fields: fields,
          config: taskConfig,
          onChanged: onTaskConfigChanged,
        ),
      ],
    );
  }
}

// --- Auto-task settings ----------------------------------------------------

/// The "create a task from each submission" panel in the Build view
/// (Automatic Task Creation from Forms).
class _TaskSettingsCard extends ConsumerWidget {
  const _TaskSettingsCard({
    required this.fields,
    required this.config,
    required this.onChanged,
  });

  final List<model.FormField> fields;
  final FormTaskConfig config;
  final ValueChanged<FormTaskConfig> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    // Only offer fields that still exist as the title source.
    final Set<String> ids = <String>{
      for (final model.FormField f in fields) f.id,
    };
    final String? titleValue = ids.contains(config.titleField)
        ? config.titleField
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              secondary: Icon(Icons.bolt_outlined, color: AppColors.amber),
              title: const Text(
                'Create a task from each submission',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'New submissions are turned into tasks automatically.',
              ),
              value: config.enabled,
              onChanged: (bool v) => onChanged(config.copyWith(enabled: v)),
            ),
            if (config.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<int?>(
                      initialValue: projects.any(
                        (Project p) => p.id == config.projectId,
                      )
                          ? config.projectId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        helperText: 'Where created tasks land',
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          child: Text('No project'),
                        ),
                        for (final Project p in projects)
                          DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                      ],
                      onChanged: (int? v) => onChanged(
                        config.copyWith(projectId: v, clearProject: v == null),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: titleValue,
                      decoration: const InputDecoration(
                        labelText: 'Use answer as task title',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          child: Text('Form name'),
                        ),
                        for (final model.FormField f in fields)
                          DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(
                              f.label.isEmpty ? 'Untitled field' : f.label,
                            ),
                          ),
                      ],
                      onChanged: (String? v) =>
                          onChanged(config.copyWith(titleField: v ?? '')),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskPriority>(
                      initialValue: TaskPriority.fromJson(config.priority),
                      decoration: const InputDecoration(
                        labelText: 'Task priority',
                      ),
                      items: <DropdownMenuItem<TaskPriority>>[
                        for (final TaskPriority p in TaskPriority.values)
                          DropdownMenuItem<TaskPriority>(
                            value: p,
                            child: Text(p.label),
                          ),
                      ],
                      onChanged: (TaskPriority? p) => onChanged(
                        config.copyWith(
                          priority: (p ?? TaskPriority.none).toJson(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tasks inherit any matching automation rules.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Fill view -------------------------------------------------------------

class _FillView extends StatelessWidget {
  const _FillView({
    required this.fields,
    required this.controllerFor,
    required this.selects,
    required this.checks,
    required this.onChanged,
    required this.onSubmit,
  });

  final List<model.FormField> fields;
  final TextEditingController Function(String id) controllerFor;
  final Map<String, String?> selects;
  final Map<String, bool> checks;
  final VoidCallback onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        for (final model.FormField f in fields) ...<Widget>[
          _label(context, f),
          const SizedBox(height: 6),
          _input(f),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Submit'),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, model.FormField f) => Row(
    children: <Widget>[
      Flexible(
        child: Text(
          f.label.isEmpty ? 'Field' : f.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      if (f.required) const Text(' *', style: TextStyle(color: AppColors.rose)),
    ],
  );

  Widget _input(model.FormField f) {
    switch (f.type) {
      case FormFieldType.checkbox:
        return _CheckboxField(
          value: checks[f.id] ?? false,
          label: f.label,
          onChanged: (bool v) {
            checks[f.id] = v;
            onChanged();
          },
        );
      case FormFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: selects[f.id],
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: <DropdownMenuItem<String>>[
            for (final String o in f.options)
              DropdownMenuItem<String>(value: o, child: Text(o)),
          ],
          onChanged: (String? v) {
            selects[f.id] = v;
            onChanged();
          },
        );
      case FormFieldType.textarea:
        return TextField(
          controller: controllerFor(f.id),
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case FormFieldType.number:
        return TextField(
          controller: controllerFor(f.id),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case FormFieldType.text:
      case FormFieldType.unknown:
        return TextField(
          controller: controllerFor(f.id),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
    }
  }
}

class _CheckboxField extends StatelessWidget {
  const _CheckboxField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (bool? v) => onChanged(v ?? false),
      title: Text(label.isEmpty ? 'Yes' : label),
    );
  }
}

// --- Responses view --------------------------------------------------------

class _ResponsesView extends ConsumerStatefulWidget {
  const _ResponsesView({required this.pageId});

  final int pageId;

  @override
  ConsumerState<_ResponsesView> createState() => _ResponsesViewState();
}

class _ResponsesViewState extends ConsumerState<_ResponsesView> {
  late Future<List<FormResponseEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(pagesRepositoryProvider).formResponses(widget.pageId);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<FormResponseEntry>>(
      future: _future,
      builder:
          (BuildContext context, AsyncSnapshot<List<FormResponseEntry>> s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return Center(
                child: Text('Could not load responses:\n${s.error}'),
              );
            }
            final List<FormResponseEntry> items =
                s.data ?? const <FormResponseEntry>[];
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'No responses yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  '${items.length} response${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final FormResponseEntry e in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(
                        e.submittedByName.isEmpty
                            ? 'Anonymous'
                            : e.submittedByName,
                      ),
                      subtitle: Text(relativeTime(e.createdAt)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: <Widget>[
                        for (final MapEntry<String, dynamic> a
                            in e.answers.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    a.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Text('${a.value}')),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
    );
  }
}

// --- Field edit dialog -----------------------------------------------------

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({required this.field, required this.newId});

  final model.FormField? field;
  final String Function() newId;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.field?.label ?? '',
  );
  late final TextEditingController _options = TextEditingController(
    text: widget.field?.options.join('\n') ?? '',
  );
  late FormFieldType _type = widget.field?.type == null
      ? FormFieldType.text
      : (widget.field!.type == FormFieldType.unknown
            ? FormFieldType.text
            : widget.field!.type);
  late bool _required = widget.field?.required ?? false;

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.field == null ? 'Add field' : 'Edit field'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _label,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Question / label'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FormFieldType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<FormFieldType>>[
                for (final FormFieldType t in FormFieldType.selectable)
                  DropdownMenuItem<FormFieldType>(
                    value: t,
                    child: Text(t.label),
                  ),
              ],
              onChanged: (FormFieldType? t) =>
                  setState(() => _type = t ?? FormFieldType.text),
            ),
            if (_type.hasOptions) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                ),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _required,
              onChanged: (bool v) => setState(() => _required = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final List<String> opts = _options.text
                .split('\n')
                .map((String s) => s.trim())
                .where((String s) => s.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              model.FormField(
                id: widget.field?.id ?? widget.newId(),
                label: _label.text.trim(),
                type: _type,
                required: _required,
                options: _type.hasOptions ? opts : const <String>[],
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
