import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/invoice_status.dart';
import '../../data/models/invoice.dart';
import 'providers/invoices_providers.dart';
import 'widgets/invoice_detail_dialog.dart';
import 'widgets/new_invoice_dialog.dart';

/// Invoices: bill a project's time and track payment through the workflow.
class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  InvoiceStatus? _filter;

  Future<void> _create() async {
    final int? id = await showNewInvoiceDialog(context);
    if (id != null && mounted) {
      await showInvoiceDetailDialog(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Invoice>> async = ref.watch(invoicesProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Invoices',
            subtitle: 'Bill time & track payments',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New invoice'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (List<Invoice> all) => _Body(
                all: all,
                filter: _filter,
                onFilter: (InvoiceStatus? s) => setState(() => _filter = s),
                onCreate: _create,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.all,
    required this.filter,
    required this.onFilter,
    required this.onCreate,
  });

  final List<Invoice> all;
  final InvoiceStatus? filter;
  final ValueChanged<InvoiceStatus?> onFilter;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'No invoices yet',
        message:
            'Generate an invoice from a project\'s unbilled time, or '
            'start a blank draft.',
        actionLabel: 'New invoice',
        actionIcon: Icons.add,
        onAction: onCreate,
      );
    }
    final List<Invoice> items = filter == null
        ? all
        : all.where((Invoice i) => i.status == filter).toList();
    final int outstanding = all
        .where((Invoice i) => i.status == InvoiceStatus.sent)
        .fold<int>(0, (int s, Invoice i) => s + i.totalCents);
    final int paid = all
        .where((Invoice i) => i.status == InvoiceStatus.paid)
        .fold<int>(0, (int s, Invoice i) => s + i.totalCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _Stat(
              label: '${formatCents(outstanding)} outstanding',
              icon: Icons.hourglass_bottom_outlined,
              warn: outstanding > 0,
            ),
            _Stat(
              label: '${formatCents(paid)} paid',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FilterBar(selected: filter, onSelect: onFilter),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int i) => _InvoiceRow(
              invoice: items[i],
              onTap: () => showInvoiceDetailDialog(context, items[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.icon, this.warn = false});
  final String label;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = warn
        ? const Color(0xFFEA580C)
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warn
            ? const Color(0xFFEA580C).withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final InvoiceStatus? selected;
  final ValueChanged<InvoiceStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final InvoiceStatus s in InvoiceStatus.values)
          ChoiceChip(
            label: Text(s.label),
            selected: selected == s,
            onSelected: (_) => onSelect(s),
          ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onTap});
  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Invoice inv = invoice;
    final List<String> meta = <String>[
      if (inv.clientName.isNotEmpty) inv.clientName,
      if (inv.projectName.isNotEmpty) inv.projectName,
      if (inv.issueDate case final DateTime d) '${shortDate(d)} ${d.year}',
      '${inv.lineCount} ${inv.lineCount == 1 ? 'line' : 'lines'}',
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DashboardCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: inv.status.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.request_quote_outlined,
                size: 20,
                color: inv.status.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    inv.number,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  formatCents(inv.totalCents),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusChip(status: inv.status),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
