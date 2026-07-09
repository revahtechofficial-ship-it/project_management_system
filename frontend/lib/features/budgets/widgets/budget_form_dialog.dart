import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/project.dart';
import '../../projects/providers/projects_providers.dart';
import '../providers/budgets_providers.dart';

/// Opens the set/edit-budget dialog. Pass [existing] to edit an existing
/// project budget; omit it to set one for a project that has none yet.
/// Returns true when a budget was saved.
Future<bool?> showBudgetFormDialog(BuildContext context, {Budget? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _BudgetFormDialog(existing: existing),
  );
}

class _BudgetFormDialog extends ConsumerStatefulWidget {
  const _BudgetFormDialog({this.existing});
  final Budget? existing;

  @override
  ConsumerState<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<_BudgetFormDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _rate;
  late final TextEditingController _notes;
  int? _projectId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Budget? b = widget.existing;
    _amount = TextEditingController(
      text: b == null || b.amountCents == 0
          ? ''
          : (b.amountCents / 100).toStringAsFixed(2),
    );
    _rate = TextEditingController(
      text: b == null || b.hourlyRateCents == 0
          ? ''
          : (b.hourlyRateCents / 100).toStringAsFixed(2),
    );
    _notes = TextEditingController(text: b?.notes ?? '');
    _projectId = b?.projectId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  int _cents(TextEditingController c) {
    final double v = double.tryParse(c.text.trim()) ?? 0;
    return (v * 100).round();
  }

  Future<void> _save() async {
    if (_projectId == null) {
      context.showError('Choose a project');
      return;
    }
    if (_cents(_amount) <= 0) {
      context.showError('Enter a budget amount');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(budgetsRepositoryProvider)
          .upsert(
            projectId: _projectId!,
            amountCents: _cents(_amount),
            hourlyRateCents: _cents(_rate),
            notes: _notes.text.trim(),
          );
      ref.invalidate(budgetsProvider);
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
    final List<Project> allProjects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final List<Budget> budgets =
        ref.watch(budgetsProvider).asData?.value ?? const <Budget>[];
    // When creating, only offer projects that don't already have a budget.
    final Set<int> taken = budgets.map((Budget b) => b.projectId).toSet();
    final List<Project> selectable = editing
        ? allProjects
        : allProjects.where((Project p) => !taken.contains(p.id)).toList();

    return AlertDialog(
      title: Text(editing ? 'Edit budget' : 'Set project budget'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.existing!.projectName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  isDense: true,
                ),
                items: <DropdownMenuItem<int>>[
                  for (final Project p in selectable)
                    DropdownMenuItem<int>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (int? v) => setState(() => _projectId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: editing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Budget amount',
                isDense: true,
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Billable hourly rate (optional)',
                isDense: true,
                prefixText: '\$ ',
                helperText: 'Applied to billable time logged on the project',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(editing ? 'Save' : 'Set budget'),
        ),
      ],
    );
  }
}
