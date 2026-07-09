import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/csv_export.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/expense_status.dart';
import '../../data/models/expense.dart';
import 'providers/expenses_providers.dart';
import 'widgets/expense_form_dialog.dart';

/// Expenses: team spend claims with an approve / reject / reimburse workflow.
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  ExpenseStatus? _filter;

  Future<void> _add() async {
    await showExpenseFormDialog(context);
  }

  void _export() {
    final List<Expense> items =
        ref.read(expensesProvider).asData?.value ?? const <Expense>[];
    if (items.isEmpty) {
      context.showError('Nothing to export');
      return;
    }
    exportCsv(
      'expenses',
      <String>[
        'Date',
        'Category',
        'Merchant',
        'Description',
        'Amount',
        'Status',
        'Project',
        'Submitter',
      ],
      <List<String>>[
        for (final Expense e in items)
          <String>[
            dateParam(e.spentOn) ?? '',
            e.category.label,
            e.merchant,
            e.description,
            (e.amountCents / 100).toStringAsFixed(2),
            e.status.label,
            e.projectName,
            e.submitterName,
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Expense>> async = ref.watch(expensesProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Expenses',
            subtitle: 'Claims & reimbursements',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export'),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('New expense'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(expensesProvider),
              ),
              data: (List<Expense> all) => _Body(
                all: all,
                filter: _filter,
                onFilter: (ExpenseStatus? s) => setState(() => _filter = s),
                onAdd: _add,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.all,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final List<Expense> all;
  final ExpenseStatus? filter;
  final ValueChanged<ExpenseStatus?> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses yet',
        message:
            'File a claim for travel, software or anything the company '
            'should reimburse.',
        actionLabel: 'File an expense',
        actionIcon: Icons.add,
        onAction: onAdd,
      );
    }
    final List<Expense> items = filter == null
        ? all
        : all.where((Expense e) => e.status == filter).toList();
    final int total = all.fold<int>(0, (int s, Expense e) => s + e.amountCents);
    final int pending = all
        .where((Expense e) => e.status == ExpenseStatus.pending)
        .fold<int>(0, (int s, Expense e) => s + e.amountCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _Stat(
              label: '${formatCents(total)} total',
              icon: Icons.summarize_outlined,
            ),
            if (pending > 0)
              _Stat(
                label: '${formatCents(pending)} pending',
                icon: Icons.hourglass_bottom_outlined,
                warn: true,
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
            itemBuilder: (BuildContext context, int i) =>
                _ExpenseRow(expense: items[i]),
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
  final ExpenseStatus? selected;
  final ValueChanged<ExpenseStatus?> onSelect;

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
        for (final ExpenseStatus s in ExpenseStatus.values)
          ChoiceChip(
            label: Text(s.label),
            selected: selected == s,
            onSelected: (_) => onSelect(s),
          ),
      ],
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});
  final Expense expense;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    ExpenseStatus status,
  ) async {
    try {
      await ref
          .read(expensesRepositoryProvider)
          .setStatus(expense.id, status.toJson());
      ref.invalidate(expensesProvider);
      if (context.mounted) {
        context.showSuccess('Marked ${status.label.toLowerCase()}');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update: $e');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete expense?'),
            content: const Text('This claim will be removed permanently.'),
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
      await ref.read(expensesRepositoryProvider).delete(expense.id);
      ref.invalidate(expensesProvider);
      if (context.mounted) {
        context.showSuccess('Expense deleted');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  /// Workflow transitions available from the current status.
  List<ExpenseStatus> get _transitions => switch (expense.status) {
    ExpenseStatus.pending => <ExpenseStatus>[
      ExpenseStatus.approved,
      ExpenseStatus.rejected,
    ],
    ExpenseStatus.approved => <ExpenseStatus>[
      ExpenseStatus.reimbursed,
      ExpenseStatus.rejected,
    ],
    ExpenseStatus.rejected => <ExpenseStatus>[ExpenseStatus.pending],
    ExpenseStatus.reimbursed => <ExpenseStatus>[],
  };

  String _labelFor(ExpenseStatus s) => switch (s) {
    ExpenseStatus.approved => 'Approve',
    ExpenseStatus.rejected => 'Reject',
    ExpenseStatus.reimbursed => 'Mark reimbursed',
    ExpenseStatus.pending => 'Re-open',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Expense e = expense;
    final List<String> meta = <String>[
      if (e.submitterName.isNotEmpty) e.submitterName,
      if (e.spentOn case final DateTime d) '${shortDate(d)} ${d.year}',
      if (e.projectName.isNotEmpty) e.projectName,
    ];
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: e.category.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(e.category.icon, size: 20, color: e.category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  e.description.isEmpty
                      ? (e.merchant.isEmpty ? e.category.label : e.merchant)
                      : e.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (meta.isNotEmpty)
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
                formatCents(e.amountCents),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              _StatusChip(status: e.status),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_horiz),
            onSelected: (String v) {
              switch (v) {
                case 'edit':
                  showExpenseFormDialog(context, existing: e);
                case 'delete':
                  _delete(context, ref);
                default:
                  _setStatus(context, ref, ExpenseStatus.fromJson(v));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final ExpenseStatus s in _transitions)
                PopupMenuItem<String>(
                  value: s.toJson(),
                  child: Text(_labelFor(s)),
                ),
              if (_transitions.isNotEmpty) const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ExpenseStatus status;

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
