import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/enums/project_status.dart';
import '../../../data/models/project.dart';
import '../providers/projects_providers.dart';

/// Create/edit dialog for a [Project]. Pops `true` on a successful save so the
/// caller can refresh the list.
class ProjectFormDialog extends ConsumerStatefulWidget {
  const ProjectFormDialog({super.key, this.project});

  final Project? project;

  @override
  ConsumerState<ProjectFormDialog> createState() =>
      _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late ProjectStatus _status;
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final Project? p = widget.project;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _status = p == null || p.status == ProjectStatus.other
        ? ProjectStatus.active
        : p.status;
    _dueDate = p?.dueDate;
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
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          status: _status,
          dueDate: _dueDate,
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
                decoration:
                    const InputDecoration(labelText: 'Description'),
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
