import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/enums/invoice_status.dart';
import '../../../data/models/invoice.dart';
import '../../../data/models/invoice_line.dart';
import '../providers/invoices_providers.dart';

/// Opens the invoice detail view for [invoiceId].
Future<void> showInvoiceDetailDialog(BuildContext context, int invoiceId) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) => _InvoiceDetailDialog(invoiceId: invoiceId),
  );
}

class _InvoiceDetailDialog extends ConsumerWidget {
  const _InvoiceDetailDialog({required this.invoiceId});
  final int invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Invoice> async = ref.watch(
      invoiceDetailProvider(invoiceId),
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: async.when(
          loading: () => const SizedBox(height: 240, child: LoadingView()),
          error: (Object e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorNotice(error: e),
          ),
          data: (Invoice inv) => _Content(invoice: inv),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.invoice});
  final Invoice invoice;

  void _refresh(WidgetRef ref) {
    ref.invalidate(invoiceDetailProvider(invoice.id));
    ref.invalidate(invoicesProvider);
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    InvoiceStatus status,
  ) async {
    try {
      await ref
          .read(invoicesRepositoryProvider)
          .setStatus(invoice.id, status.toJson());
      _refresh(ref);
      if (context.mounted) {
        context.showSuccess('Marked ${status.label.toLowerCase()}');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update: $e');
      }
    }
  }

  Future<void> _addLine(BuildContext context, WidgetRef ref) async {
    final _NewLine? line = await showDialog<_NewLine>(
      context: context,
      builder: (BuildContext _) => const _AddLineDialog(),
    );
    if (line == null) {
      return;
    }
    try {
      await ref
          .read(invoicesRepositoryProvider)
          .addLine(
            invoice.id,
            description: line.description,
            amountCents: line.amountCents,
          );
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not add line: $e');
      }
    }
  }

  Future<void> _deleteLine(
    BuildContext context,
    WidgetRef ref,
    int lineId,
  ) async {
    try {
      await ref.read(invoicesRepositoryProvider).deleteLine(invoice.id, lineId);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove line: $e');
      }
    }
  }

  Future<void> _deleteInvoice(BuildContext context, WidgetRef ref) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete invoice?'),
            content: Text(
              'Delete ${invoice.number}? Any time it billed is '
              'released back to unbilled.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(invoicesRepositoryProvider).delete(invoice.id);
      ref.invalidate(invoicesProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
        context.showSuccess('Invoice deleted');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Invoice inv = invoice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: <Widget>[
              Text(
                inv.number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(status: inv.status),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MetaLine(invoice: inv),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Flexible(
          child: inv.lines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No line items yet.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: inv.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) => _LineRow(
                    line: inv.lines[i],
                    onDelete: () => _deleteLine(context, ref, inv.lines[i].id),
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _addLine(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add line'),
              ),
              const Spacer(),
              Text('Total', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 10),
              Text(
                formatCents(inv.totalCents),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Delete invoice',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _deleteInvoice(context, ref),
              ),
              const Spacer(),
              if (inv.status != InvoiceStatus.void_)
                TextButton(
                  onPressed: () =>
                      _setStatus(context, ref, InvoiceStatus.void_),
                  child: const Text('Void'),
                ),
              const SizedBox(width: 8),
              ..._statusAction(context, ref, inv.status),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _statusAction(
    BuildContext context,
    WidgetRef ref,
    InvoiceStatus status,
  ) {
    return switch (status) {
      InvoiceStatus.draft => <Widget>[
        FilledButton(
          onPressed: () => _setStatus(context, ref, InvoiceStatus.sent),
          child: const Text('Mark sent'),
        ),
      ],
      InvoiceStatus.sent => <Widget>[
        FilledButton(
          onPressed: () => _setStatus(context, ref, InvoiceStatus.paid),
          child: const Text('Mark paid'),
        ),
      ],
      InvoiceStatus.paid || InvoiceStatus.void_ => <Widget>[],
    };
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Invoice inv = invoice;
    final List<String> parts = <String>[
      if (inv.clientName.isNotEmpty) inv.clientName,
      if (inv.projectName.isNotEmpty) inv.projectName,
      if (inv.issueDate case final DateTime d)
        'Issued ${shortDate(d)} ${d.year}',
      if (inv.dueDate case final DateTime d) 'Due ${shortDate(d)} ${d.year}',
    ];
    return Text(
      parts.isEmpty ? 'No client set' : parts.join('  ·  '),
      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.onDelete});
  final InvoiceLine line;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool timed = line.quantityMinutes > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  line.description.isEmpty ? 'Item' : line.description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (timed)
                  Text(
                    '${line.hours.toStringAsFixed(1)} h @ '
                    '${formatCents(line.rateCents)}/h',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCents(line.amountCents),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Remove line',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The result of the add-line dialog.
class _NewLine {
  const _NewLine(this.description, this.amountCents);
  final String description;
  final int amountCents;
}

class _AddLineDialog extends StatefulWidget {
  const _AddLineDialog();

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final double v = double.tryParse(_amount.text.trim()) ?? 0;
    final int cents = (v * 100).round();
    if (_description.text.trim().isEmpty || cents <= 0) {
      return;
    }
    Navigator.of(context).pop(_NewLine(_description.text.trim(), cents));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add line item'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _description,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Description',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                isDense: true,
                prefixText: '\$ ',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
