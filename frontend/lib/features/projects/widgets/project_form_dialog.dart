import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../data/enums/project_status.dart';
import '../../../data/models/folder.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_template.dart';
import '../../../data/models/space.dart';
import '../providers/project_templates_providers.dart';
import '../providers/projects_providers.dart';
import '../providers/spaces_providers.dart';

/// Create/edit dialog for a [Project]. Pops `true` on a successful save so the
/// caller can refresh the list.
class ProjectFormDialog extends ConsumerStatefulWidget {
  const ProjectFormDialog({super.key, this.project, this.template});

  final Project? project;

  /// When creating (project == null), pre-fills the form from this template.
  final ProjectTemplate? template;

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late ProjectStatus _status;
  DateTime? _dueDate;
  int? _spaceId;
  int? _folderId;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final Project? p = widget.project;
    final ProjectTemplate? tmpl = widget.template;
    _name = TextEditingController(text: p?.name ?? tmpl?.projectName ?? '');
    _description = TextEditingController(
      text: p?.description ?? tmpl?.description ?? '',
    );
    _status = p != null
        ? (p.status == ProjectStatus.other ? ProjectStatus.active : p.status)
        : (tmpl != null && tmpl.status != ProjectStatus.other
              ? tmpl.status
              : ProjectStatus.active);
    _dueDate = p?.dueDate;
    _spaceId = p?.spaceId;
    _folderId = p?.folderId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(projectsRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.project!.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          status: _status,
          dueDate: _dueDate,
          spaceId: _spaceId,
          folderId: _folderId,
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          status: _status,
          dueDate: _dueDate,
          spaceId: _spaceId,
          folderId: _folderId,
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

  /// Saves the current field values as a reusable named project template.
  Future<void> _saveAsTemplate() async {
    final TextEditingController nameCtrl = TextEditingController(
      text: _name.text.trim(),
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
          .read(projectTemplatesRepositoryProvider)
          .create(
            name: name,
            projectName: _name.text.trim(),
            description: _description.text.trim(),
            status: _status,
          );
      ref.invalidate(projectTemplatesProvider);
      if (mounted) {
        context.showSuccess('Saved template "$name"');
      }
    } catch (_) {
      if (mounted) {
        context.showError('Could not save template');
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Space> spaces =
        ref.watch(spacesProvider).asData?.value ?? const <Space>[];
    final List<Folder> folders =
        (ref.watch(foldersProvider).asData?.value ?? const <Folder>[])
            .where((Folder f) => f.spaceId == _spaceId)
            .toList(growable: false);
    return AlertDialog(
      title: Text(_isEdit ? 'Edit project' : 'New project'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
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
              DropdownButtonFormField<ProjectStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: <DropdownMenuItem<ProjectStatus>>[
                  for (final ProjectStatus s in ProjectStatus.values)
                    if (s != ProjectStatus.other)
                      DropdownMenuItem<ProjectStatus>(
                        value: s,
                        child: Text(s.label),
                      ),
                ],
                onChanged: (ProjectStatus? v) =>
                    setState(() => _status = v ?? ProjectStatus.active),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: spaces.any((Space s) => s.id == _spaceId)
                    ? _spaceId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Space',
                  prefixIcon: Icon(Icons.workspaces_outline, size: 20),
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No space'),
                  ),
                  for (final Space s in spaces)
                    DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
                ],
                onChanged: (int? v) => setState(() {
                  _spaceId = v;
                  _folderId = null;
                }),
              ),
              if (_spaceId != null) ...<Widget>[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: folders.any((Folder f) => f.id == _folderId)
                      ? _folderId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                    prefixIcon: Icon(Icons.folder_outlined, size: 20),
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No folder'),
                    ),
                    for (final Folder f in folders)
                      DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
                  ],
                  onChanged: (int? v) => setState(() => _folderId = v),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    suffixIcon: Icon(Icons.event),
                  ),
                  child: Text(
                    _dueDate == null ? 'No due date' : shortDate(_dueDate!),
                  ),
                ),
              ),
              if (_dueDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _dueDate = null),
                    child: const Text('Clear date'),
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
