import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/key_result.dart';
import '../../data/models/objective.dart';
import 'providers/goals_providers.dart';
import 'widgets/key_result_dialog.dart';
import 'widgets/objective_dialog.dart';

/// Goals & OKRs: objectives with measurable key results, progress, owners and
/// alignment (a parent objective). The progress dashboard for the team
/// (AGENTS.md §1 feature page).
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  Future<void> _newObjective(
    BuildContext context,
    WidgetRef ref,
    List<Objective> objectives,
  ) async {
    await showObjectiveDialog(context, objectives: objectives);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Objective>> async = ref.watch(objectivesProvider);
    final List<Objective> all = async.asData?.value ?? const <Objective>[];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Goals',
            subtitle: 'Objectives, key results and alignment',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => _newObjective(context, ref, all),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New goal'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) =>
                  Center(child: Text('Failed to load goals:\n$e')),
              data: (List<Objective> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.flag_outlined,
                    message: 'No goals yet. Create your first objective.',
                  );
                }
                return _GoalsList(objectives: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsList extends StatelessWidget {
  const _GoalsList({required this.objectives});

  final List<Objective> objectives;

  @override
  Widget build(BuildContext context) {
    final Set<int> ids = <int>{for (final Objective o in objectives) o.id};
    final Map<int?, List<Objective>> byParent = <int?, List<Objective>>{};
    for (final Objective o in objectives) {
      final int? key = (o.parentId != null && ids.contains(o.parentId))
          ? o.parentId
          : null;
      byParent.putIfAbsent(key, () => <Objective>[]).add(o);
    }
    final double avg = objectives.isEmpty
        ? 0
        : objectives.fold<double>(
                0,
                (double s, Objective o) => s + o.progress,
              ) /
              objectives.length;

    final List<Widget> rows = <Widget>[
      _OverallCard(count: objectives.length, avg: avg),
      const SizedBox(height: 16),
    ];
    void walk(int? parent, int depth) {
      for (final Objective o in byParent[parent] ?? const <Objective>[]) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: depth * 24.0, bottom: 12),
            child: _ObjectiveCard(objective: o, objectives: objectives),
          ),
        );
        walk(o.id, depth + 1);
      }
    }

    walk(null, 0);
    return ListView(children: rows);
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.count, required this.avg});

  final int count;
  final double avg;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.flag_circle_outlined, color: AppColors.brand, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count ${count == 1 ? 'goal' : 'goals'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: avg,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(avg * 100).round()}%',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveCard extends ConsumerWidget {
  const _ObjectiveCard({required this.objective, required this.objectives});

  final Objective objective;
  final List<Objective> objectives;

  Future<void> _edit(BuildContext context) =>
      showObjectiveDialog(context, existing: objective, objectives: objectives);

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Delete "${objective.title}"?'),
            content: const Text(
              'The objective and its key results are removed.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    await ref.read(objectivesRepositoryProvider).delete(objective.id);
    ref.invalidate(objectivesProvider);
  }

  Future<void> _deleteKr(WidgetRef ref, int krId) async {
    await ref.read(objectivesRepositoryProvider).deleteKeyResult(krId);
    ref.invalidate(objectivesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  objective.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: objective.status.label,
                color: objective.status.color,
              ),
              if (objective.canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (String v) {
                    if (v == 'edit') {
                      _edit(context);
                    } else if (v == 'kr') {
                      showKeyResultDialog(context, objectiveId: objective.id);
                    } else if (v == 'delete') {
                      _delete(context, ref);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit objective'),
                        ),
                        PopupMenuItem<String>(
                          value: 'kr',
                          child: Text('Add key result'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                ),
            ],
          ),
          if (objective.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              objective.description,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (objective.ownerName.isNotEmpty) ...<Widget>[
                UserAvatar(name: objective.ownerName, radius: 11),
                const SizedBox(width: 6),
                Text(
                  objective.ownerName,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (objective.period.isNotEmpty)
                Text(
                  objective.period,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              Text(
                '${objective.percent}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: objective.progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(objective.status.color),
            ),
          ),
          if (objective.keyResults.isNotEmpty) ...<Widget>[
            const Divider(height: 24),
            for (final KeyResult kr in objective.keyResults)
              _KrRow(
                kr: kr,
                canManage: objective.canManage,
                onEdit: () => showKeyResultDialog(
                  context,
                  objectiveId: objective.id,
                  existing: kr,
                ),
                onDelete: () => _deleteKr(ref, kr.id),
              ),
          ],
          if (objective.canManage && objective.keyResults.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    showKeyResultDialog(context, objectiveId: objective.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add key result'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KrRow extends StatelessWidget {
  const _KrRow({
    required this.kr,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final KeyResult kr;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: canManage ? onEdit : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    kr.title.isEmpty ? 'Key result' : kr.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  kr.valueLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (canManage)
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: kr.progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
