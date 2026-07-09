import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/revah_logo.dart';
import '../../data/models/shared_project.dart';
import 'providers/project_share_providers.dart';

/// A public, read-only view of a shared project reached via a share token. It
/// renders standalone (no app shell) so signed-out visitors can open it.
class SharedProjectPage extends ConsumerWidget {
  const SharedProjectPage({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SharedProject> async = ref.watch(
      sharedProjectProvider(token),
    );
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _Header(),
              Expanded(
                child: async.when(
                  loading: () => const LoadingView(),
                  error: (Object e, _) => const _Invalid(),
                  data: (SharedProject p) => _Body(project: p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          const RevahLogo(height: 26),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Read-only shared view',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.project});
  final SharedProject project;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int total = project.tasks.length;
    final double progress = total == 0 ? 0 : project.doneCount / total;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              project.name.isEmpty ? 'Project' : project.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            if (project.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                project.description,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            DashboardCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${project.doneCount} of $total tasks done',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const EmptyState(
                icon: Icons.checklist_rounded,
                message: 'No tasks in this project yet.',
              )
            else
              DashboardCard(
                title: 'Tasks',
                child: Column(
                  children: <Widget>[
                    for (final SharedTask t in project.tasks) _TaskRow(task: t),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final SharedTask task;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        task.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: task.done ? AppColors.green : scheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? scheme.onSurfaceVariant : null,
        ),
      ),
      trailing: task.dueDate == null
          ? null
          : Text(
              shortDate(task.dueDate!.toLocal()),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
    );
  }
}

class _Invalid extends StatelessWidget {
  const _Invalid();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.link_off_rounded,
      title: 'Link not available',
      message: 'This share link is invalid or has been turned off.',
    );
  }
}
