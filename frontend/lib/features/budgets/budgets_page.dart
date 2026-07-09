import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/budget.dart';
import 'providers/budgets_providers.dart';
import 'widgets/budget_form_dialog.dart';

/// Budgets: a spending cap per project with actual cost tracked from approved
/// expenses and billable time.
class BudgetsPage extends ConsumerStatefulWidget {
  const BudgetsPage({super.key});

  @override
  ConsumerState<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends ConsumerState<BudgetsPage> {
  Future<void> _add() async {
    await showBudgetFormDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Budget>> async = ref.watch(budgetsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Budgets',
            subtitle: 'Project cost tracking',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Set budget'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(budgetsProvider),
              ),
              data: (List<Budget> budgets) =>
                  _Body(budgets: budgets, onAdd: _add),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.budgets, required this.onAdd});
  final List<Budget> budgets;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No budgets set',
        message:
            'Set a budget on a project to track spend from expenses and '
            'billable time against a cap.',
        actionLabel: 'Set the first budget',
        actionIcon: Icons.add,
        onAction: onAdd,
      );
    }
    final int totalBudget = budgets.fold<int>(
      0,
      (int s, Budget b) => s + b.amountCents,
    );
    final int totalActual = budgets.fold<int>(
      0,
      (int s, Budget b) => s + b.actualCents,
    );
    final int over = budgets.where((Budget b) => b.overBudget).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _Stat(
              label: '${formatCents(totalBudget)} budgeted',
              icon: Icons.account_balance_wallet_outlined,
            ),
            _Stat(
              label: '${formatCents(totalActual)} spent',
              icon: Icons.payments_outlined,
            ),
            if (over > 0)
              _Stat(
                label: '$over over budget',
                icon: Icons.warning_amber_rounded,
                warn: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (final Budget b in budgets)
                  SizedBox(width: 380, child: _BudgetCard(budget: b)),
              ],
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

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.budget});
  final Budget budget;

  Color _health() {
    if (budget.overBudget) {
      return AppColors.rose;
    }
    if (budget.usedFraction >= 0.75) {
      return AppColors.amber;
    }
    return AppColors.green;
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Remove budget?'),
            content: Text(
              'Stop tracking a budget for '
              '"${budget.projectName}"?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(budgetsRepositoryProvider).delete(budget.id);
      ref.invalidate(budgetsProvider);
      if (context.mounted) {
        context.showSuccess('Budget removed');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color health = _health();
    final Budget b = budget;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  b.projectName.isEmpty
                      ? 'Project #${b.projectId}'
                      : b.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_horiz),
                onSelected: (String v) {
                  switch (v) {
                    case 'edit':
                      showBudgetFormDialog(context, existing: b);
                    case 'delete':
                      _delete(context, ref);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Remove'),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                formatCents(b.actualCents),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: health,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'of ${formatCents(b.amountCents)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: b.usedFraction,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(health),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            b.overBudget
                ? '${formatCents(-b.remainingCents)} over budget'
                : '${formatCents(b.remainingCents)} remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: b.overBudget ? AppColors.rose : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _BreakdownRow(
            icon: Icons.receipt_long_outlined,
            label: 'Expenses',
            value: formatCents(b.expenseCents),
          ),
          const SizedBox(height: 6),
          _BreakdownRow(
            icon: Icons.schedule_outlined,
            label: b.hourlyRateCents > 0
                ? 'Labor · ${b.billableHours.toStringAsFixed(1)}h @ '
                      '${formatCents(b.hourlyRateCents)}/h'
                : 'Labor · ${b.billableHours.toStringAsFixed(1)}h billable',
            value: formatCents(b.laborCents),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
