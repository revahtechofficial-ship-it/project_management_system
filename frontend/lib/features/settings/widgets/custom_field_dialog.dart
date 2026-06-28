import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/enums/custom_field_type.dart';
import '../../tasks/providers/custom_fields_providers.dart';

/// Opens the "new custom field" dialog. Returns true if a field was created.
Future<bool?> showCustomFieldDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => const _CustomFieldDialog(),
  );
}

class _CustomFieldDialog extends ConsumerStatefulWidget {
  const _CustomFieldDialog();

  @override
  ConsumerState<_CustomFieldDialog> createState() => _CustomFieldDialogState();
}

class _CustomFieldDialogState extends ConsumerState<_CustomFieldDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _option = TextEditingController();
  CustomFieldType _type = CustomFieldType.text;
  final List<String> _options = <String>[];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _option.dispose();
    super.dispose();
  }

  void _addOption() {
    final String o = _option.text.trim();
    if (o.isEmpty || _options.contains(o)) {
      return;
    }
    setState(() {
      _options.add(o);
      _option.clear();
    });
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (_type == CustomFieldType.select && _options.isEmpty) {
      context.showSuccess('Add at least one dropdown option');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(customFieldsRepositoryProvider).create(
            name: name,
            type: _type,
            options: _options,
          );
      ref.invalidate(customFieldsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showError('Could not create field: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New custom field'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Field name',
                hintText: 'e.g. Story points, Client, Severity',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CustomFieldType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<CustomFieldType>>[
                for (final CustomFieldType t in CustomFieldType.selectableValue)
                  DropdownMenuItem<CustomFieldType>(
                    value: t,
                    child: Row(
                      children: <Widget>[
                        Icon(t.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (CustomFieldType? t) =>
                  setState(() => _type = t ?? CustomFieldType.text),
            ),
            if (_type == CustomFieldType.select) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _option,
                      onSubmitted: (_) => _addOption(),
                      decoration: const InputDecoration(
                        labelText: 'Add option',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addOption,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String o in _options)
                    Chip(
                      label: Text(o),
                      onDeleted: () => setState(() => _options.remove(o)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: Text(_saving ? 'Creating…' : 'Create'),
        ),
      ],
    );
  }
}
