import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/project.dart';
import '../../projects/providers/projects_providers.dart';
import '../providers/invoices_providers.dart';

/// Opens the new-invoice dialog. Returns the created invoice's id, so the
/// caller can open its detail view.
Future<int?> showNewInvoiceDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext _) => const _NewInvoiceDialog(),
  );
}

class _NewInvoiceDialog extends ConsumerStatefulWidget {
  const _NewInvoiceDialog();

  @override
  ConsumerState<_NewInvoiceDialog> createState() => _NewInvoiceDialogState();
}

class _NewInvoiceDialogState extends ConsumerState<_NewInvoiceDialog> {
  final TextEditingController _client = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  int? _projectId;
  DateTime? _issueDate = DateTime.now();
  DateTime? _dueDate;
  bool _fromTime = true;
  bool _busy = false;

  @override
  void dispose() {
    _client.dispose();
    _email.dispose();
    _rate.dispose();
    super.dispose();
  }

  int _rateCents() {
    final double v = double.tryParse(_rate.text.trim()) ?? 0;
    return (v * 100).round();
  }

  Future<void> _pickDate(bool issue) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (issue ? _issueDate : _dueDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (issue) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_fromTime && _projectId == null) {
      context.showError('Choose a project to bill time from');
      return;
    }
    setState(() => _busy = true);
    try {
      final Invoice inv;
      if (_fromTime) {
        inv = await ref.read(invoicesRepositoryProvider).generate(
              projectId: _projectId!,
              clientName: _client.text.trim(),
              clientEmail: _email.text.trim(),
              rateCents: _rateCents(),
              issueDate: _issueDate,
              dueDate: _dueDate,
            );
      } else {
        inv = await ref.read(invoicesRepositoryProvider).create(
              projectId: _projectId,
              clientName: _client.text.trim(),
              clientEmail: _email.text.trim(),
              issueDate: _issueDate,
              dueDate: _dueDate,
            );
      }
      ref.invalidate(invoicesProvider);
      if (mounted) {
        Navigator.of(context).pop(inv.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not create: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    return AlertDialog(
      title: const Text('New invoice'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _client,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Bill to (client)', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Client email (optional)', isDense: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Project', isDense: true),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(child: Text('No project')),
                  for (final Project p in projects)
                    DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (int? v) => setState(() => _projectId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateField(
                      label: 'Issue date',
                      value: _issueDate,
                      onPick: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Due date',
                      value: _dueDate,
                      onPick: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fromTime,
                title: const Text('Bill unbilled time from this project'),
                subtitle: const Text(
                    'Pulls billable hours not yet on an invoice'),
                onChanged: (bool v) => setState(() => _fromTime = v),
              ),
              if (_fromTime)
                TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Hourly rate override (optional)',
                    isDense: true,
                    prefixText: '\$ ',
                    helperText: "Defaults to the project budget's rate",
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_fromTime ? 'Generate' : 'Create draft'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final DateTime? v = value;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
        ),
        child: Text(v == null ? '—' : '${shortDate(v)} ${v.year}'),
      ),
    );
  }
}
