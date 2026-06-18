import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/models/sprint.dart';
import '../providers/sprints_providers.dart';

/// Create/edit dialog for a [Sprint]. Pops `true` on a successful save.
class SprintFormDialog extends ConsumerStatefulWidget {
  const SprintFormDialog({super.key, this.sprint});

  final Sprint? sprint;

  @override
  ConsumerState<SprintFormDialog> createState() => _SprintFormDialogState();
}

class _SprintFormDialogState extends ConsumerState<SprintFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _goal;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.sprint != null;

  @override
  void initState() {
    super.initState();
    final Sprint? s = widget.sprint;
    _name = TextEditingController(text: s?.name ?? '');
    _goal = TextEditingController(text: s?.goal ?? '');
    _start = s?.startDate;
    _end = s?.endDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      setState(() => _error = 'End date cannot be before the start date');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(sprintsRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.sprint!.id,
          name: _name.text.trim(),
          goal: _goal.text.trim(),
          startDate: _start,
          endDate: _end,
        );
      } else {
        await repo.create(
          name: _name.text.trim(),
          goal: _goal.text.trim(),
          startDate: _start,
          endDate: _end,
        );
      }
      ref.invalidate(sprintsProvider);
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit sprint' : 'New sprint'),
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
                controller: _goal,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Goal'),
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
                      label: 'End',
                      value: _end,
                      onTap: () => _pick(false),
                      onClear: () => setState(() => _end = null),
                    ),
                  ),
                ],
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
