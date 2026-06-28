import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/release.dart';
import '../../data/models/task.dart';
import '../../providers/auth_provider.dart';
import '../tasks/providers/tasks_providers.dart';
import 'providers/releases_providers.dart';
import 'widgets/release_dialog.dart';

/// Release planning: versions with a target date and status, each tracking the
/// completion of the tasks assigned to it (AGENTS.md §1 feature page).
class ReleasesPage extends ConsumerWidget {
  const ReleasesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Release>> async = ref.watch(releasesProvider);
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final bool isAdmin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Releases',
            subtitle: 'Plan versions and track what ships in each',
            actions: <Widget>[
              if (isAdmin)
                FilledButton.icon(
                  onPressed: () => showReleaseDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New release'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(releasesProvider),
              ),
              data: (List<Release> releases) {
                if (releases.isEmpty) {
                  return const EmptyState(
                    icon: Icons.rocket_launch_outlined,
                    message: 'No releases yet. Plan one to group work into a '
                        'version.',
                  );
                }
                return ListView.separated(
                  itemCount: releases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int i) => _ReleaseCard(
                    release: releases[i],
                    tasks: tasks,
                    canManage: isAdmin,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends ConsumerWidget {
  const _ReleaseCard({
    required this.release,
    required this.tasks,
    required this.canManage,
  });

  final Release release;
  final List<Task> tasks;
  final bool canManage;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Delete "${release.displayName}"?'),
            content: const Text(
              'The release is removed; its tasks are kept (just unassigned).',
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
    await ref.read(releasesRepositoryProvider).delete(release.id);
    ref.invalidate(releasesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> mine = tasks
        .where((Task t) => t.releaseId == release.id && t.parentId == null)
        .toList(growable: false);
    final int total = mine.length;
    final int done = mine.where((Task t) => t.done).length;
    final double progress = total == 0 ? 0 : done / total;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.rocket_launch_outlined, color: release.status.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  release.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: release.status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  release.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: release.status.color,
                  ),
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (String v) {
                    if (v == 'edit') {
                      showReleaseDialog(context, existing: release);
                    } else if (v == 'delete') {
                      _delete(context, ref);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.event_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                release.targetDate == null
                    ? 'No target date'
                    : 'Target ${shortDate(release.targetDate!.toLocal())}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '$done / $total done',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(release.status.color),
            ),
          ),
          if (release.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              release.notes,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
