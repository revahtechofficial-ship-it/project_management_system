import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/models/checklist_template.dart';
import '../../../data/repositories/checklist_templates_repository.dart';
import '../providers/checklist_templates_providers.dart';

/// Opens the create/edit dialog for a [ChecklistTemplate]. Pass [existing] to
/// edit. Returns true when saved.
Future<bool?> showChecklistTemplateDialog(
  BuildContext context, {
  ChecklistTemplate? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _ChecklistTemplateDialog(existing: existing),
  );
}

class _ChecklistTemplateDialog extends ConsumerStatefulWidget {
  const _ChecklistTemplateDialog({this.existing});
  final ChecklistTemplate? existing;

  @override
  ConsumerState<_ChecklistTemplateDialog> createState() =>
      _ChecklistTemplateDialogState();
}

class _ChecklistTemplateDialogState
    extends ConsumerState<_ChecklistTemplateDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final List<TextEditingController> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final ChecklistTemplate? t = widget.existing;
    _name = TextEditingController(text: t?.name ?? '');
    _category = TextEditingController(text: t?.category ?? '');
    _items = <TextEditingController>[
      for (final String i in t?.items ?? const <String>[])
        TextEditingController(text: i),
      if (t == null || t.items.isEmpty) TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    for (final TextEditingController c in _items) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      context.showError('A name is required');
      return;
    }
    final List<String> items = <String>[
      for (final TextEditingController c in _items)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    setState(() => _busy = true);
    try {
      final ChecklistTemplatesRepository repo = ref.read(
        checklistTemplatesRepositoryProvider,
      );
      if (widget.existing == null) {
        await repo.create(
          name: _name.text.trim(),
          category: _category.text.trim(),
          items: items,
        );
      } else {
        await repo.update(
          widget.existing!.id,
          name: _name.text.trim(),
          category: _category.text.trim(),
          items: items,
        );
      }
      ref.invalidate(checklistTemplatesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.checklist),
                  const SizedBox(width: 10),
                  Text(
                    editing ? 'Edit checklist' : 'New checklist template',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _name,
                      autofocus: !editing,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        isDense: true,
                        hintText: 'e.g. Engineering, Onboarding',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Items',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (int i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.check_box_outline_blank, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _items[i],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Checklist item',
                                ),
                                onSubmitted: (_) => setState(
                                  () => _items.add(TextEditingController()),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                _items.removeAt(i).dispose();
                                if (_items.isEmpty) {
                                  _items.add(TextEditingController());
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _items.add(TextEditingController())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(editing ? 'Save' : 'Create'),
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
