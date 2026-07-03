import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../data/enums/expense_category.dart';
import '../../../data/enums/expense_status.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/project.dart';
import '../../../data/repositories/expenses_repository.dart';
import '../../projects/providers/projects_providers.dart';
import '../providers/expenses_providers.dart';

/// Opens the create/edit dialog for an [Expense]. Pass [existing] to edit;
/// omit it to file a new claim. Returns true when something was saved.
Future<bool?> showExpenseFormDialog(BuildContext context, {Expense? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _ExpenseFormDialog(existing: existing),
  );
}

class _ExpenseFormDialog extends ConsumerStatefulWidget {
  const _ExpenseFormDialog({this.existing});
  final Expense? existing;

  @override
  ConsumerState<_ExpenseFormDialog> createState() =>
      _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<_ExpenseFormDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _description;
  late final TextEditingController _receipt;
  late ExpenseCategory _category;
  int? _projectId;
  DateTime? _spentOn;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Expense? e = widget.existing;
    _amount = TextEditingController(
      text: e == null || e.amountCents == 0 ? '' : e.amount.toStringAsFixed(2),
    );
    _merchant = TextEditingController(text: e?.merchant ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _receipt = TextEditingController(text: e?.receiptUrl ?? '');
    _category = e?.category ?? ExpenseCategory.other;
    _projectId = e?.projectId;
    _spentOn = e?.spentOn;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _description.dispose();
    _receipt.dispose();
    super.dispose();
  }

  int _amountCents() {
    final double v = double.tryParse(_amount.text.trim()) ?? 0;
    return (v * 100).round();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _spentOn ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _spentOn = picked);
    }
  }

  Future<void> _save() async {
    if (_amountCents() <= 0 || _busy) {
      context.showError('Enter an amount greater than zero');
      return;
    }
    setState(() => _busy = true);
    final Expense payload = Expense(
      id: widget.existing?.id ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      status: widget.existing?.status ?? ExpenseStatus.pending,
      projectId: _projectId,
      category: _category,
      amountCents: _amountCents(),
      spentOn: _spentOn,
      description: _description.text.trim(),
      merchant: _merchant.text.trim(),
      receiptUrl: _receipt.text.trim(),
    );
    try {
      final ExpensesRepository repo = ref.read(expensesRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      ref.invalidate(expensesProvider);
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
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final bool editing = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  Icon(_category.icon, color: _category.color),
                  const SizedBox(width: 10),
                  Text(
                    editing ? 'Edit expense' : 'New expense',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
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
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            autofocus: !editing,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              isDense: true,
                              prefixText: '\$ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ExpenseCategory>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Category', isDense: true),
                            items: <DropdownMenuItem<ExpenseCategory>>[
                              for (final ExpenseCategory c
                                  in ExpenseCategory.values)
                                DropdownMenuItem<ExpenseCategory>(
                                  value: c,
                                  child: Text(c.label),
                                ),
                            ],
                            onChanged: (ExpenseCategory? v) =>
                                setState(() => _category = v ?? _category),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _merchant,
                      decoration: const InputDecoration(
                          labelText: 'Merchant / payee', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      value: _spentOn,
                      onPick: _pickDate,
                      onClear: () => setState(() => _spentOn = null),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _projectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Project (optional)', isDense: true),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          child: Text('No project'),
                        ),
                        for (final Project p in projects)
                          DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (int? v) => setState(() => _projectId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Description', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _receipt,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Receipt link (optional)',
                        isDense: true,
                        prefixIcon: Icon(Icons.link, size: 18),
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
                    child: Text(editing ? 'Save' : 'Submit'),
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

/// A read-only field that shows the spend date and opens a picker on tap.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onPick,
    required this.onClear,
  });
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final DateTime? v = value;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date spent',
          isDense: true,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          suffixIcon: v == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(v == null ? '—' : '${shortDate(v)} ${v.year}'),
      ),
    );
  }
}
