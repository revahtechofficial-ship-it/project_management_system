import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/custom_field_type.dart';
import '../../../data/models/custom_field.dart';
import '../providers/custom_fields_providers.dart';

/// The "Custom fields" section of the task dialog: one typed input per
/// workspace-defined field, persisting each value as it changes.
class TaskCustomFieldsSection extends ConsumerStatefulWidget {
  const TaskCustomFieldsSection({super.key, required this.taskId});
  final int taskId;

  @override
  ConsumerState<TaskCustomFieldsSection> createState() =>
      _TaskCustomFieldsSectionState();
}

class _TaskCustomFieldsSectionState
    extends ConsumerState<TaskCustomFieldsSection> {
  Map<int, String> _values = <int, String>{};
  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Map<int, String> v = await ref
          .read(customFieldsRepositoryProvider)
          .taskValues(widget.taskId);
      if (mounted) {
        setState(() {
          _values = v;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  TextEditingController _ctrl(int id) => _controllers.putIfAbsent(
    id,
    () => TextEditingController(text: _values[id] ?? ''),
  );

  Future<void> _save(int id, String value) async {
    _values[id] = value;
    try {
      await ref
          .read(customFieldsRepositoryProvider)
          .setTaskValue(widget.taskId, id, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save field: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CustomField> defs =
        ref.watch(customFieldsProvider).asData?.value ?? const <CustomField>[];
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (defs.isEmpty) {
      return Text(
        'No custom fields yet. An admin can add them in Settings.',
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final CustomField f in defs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _input(f),
          ),
      ],
    );
  }

  Widget _input(CustomField f) {
    switch (f.type) {
      case CustomFieldType.checkbox:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.name),
          value: _values[f.id] == 'true',
          onChanged: (bool b) {
            setState(() => _values[f.id] = b ? 'true' : '');
            _save(f.id, b ? 'true' : '');
          },
        );
      case CustomFieldType.select:
        final String current = _values[f.id] ?? '';
        return DropdownButtonFormField<String>(
          initialValue: f.options.contains(current) ? current : null,
          decoration: InputDecoration(labelText: f.name, isDense: true),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(value: '', child: Text('—')),
            for (final String o in f.options)
              DropdownMenuItem<String>(value: o, child: Text(o)),
          ],
          onChanged: (String? v) {
            setState(() => _values[f.id] = v ?? '');
            _save(f.id, v ?? '');
          },
        );
      case CustomFieldType.date:
        return _DateField(
          label: f.name,
          value: _values[f.id] ?? '',
          onChanged: (String v) {
            setState(() => _values[f.id] = v);
            _save(f.id, v);
          },
        );
      case CustomFieldType.number:
      case CustomFieldType.text:
      case CustomFieldType.other:
        return Focus(
          onFocusChange: (bool has) {
            if (!has) {
              _save(f.id, _ctrl(f.id).text);
            }
          },
          child: TextField(
            controller: _ctrl(f.id),
            keyboardType: f.type == CustomFieldType.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(labelText: f.name, isDense: true),
            onSubmitted: (String v) => _save(f.id, v),
          ),
        );
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        suffixIcon: value.isEmpty
            ? const Icon(Icons.event, size: 18)
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => onChanged(''),
              ),
      ),
      child: InkWell(
        onTap: () async {
          final DateTime now = DateTime.now();
          final DateTime initial = DateTime.tryParse(value) ?? now;
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 5),
          );
          if (picked != null) {
            onChanged(
              '${picked.year}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}',
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(value.isEmpty ? 'Pick a date' : value),
        ),
      ),
    );
  }
}
