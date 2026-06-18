import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/project_status.dart';
import '../../data/models/project.dart';
import '../../data/models/project_template.dart';
import '../../providers/auth_provider.dart';
import 'providers/project_templates_providers.dart';
import 'providers/projects_providers.dart';
import 'widgets/project_form_dialog.dart';

/// The projects board: delivery status, progress and team per project — all
/// backed by the live `/api/v1/projects` API.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projectsAsync = ref.watch(projectsProvider);
    final List<Project> projects =
        projectsAsync.asData?.value ?? const <Project>[];
    final int active = projects
        .where((Project p) => p.status == ProjectStatus.active)
        .length;
    final int completed = projects
        .where((Project p) => p.status == ProjectStatus.completed)
        .length;
    final double avg = projects.isEmpty
        ? 0
        : projects.fold<double>(0, (double s, Project p) => s + p.progress) /
              projects.length;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int overdue = projects
        .where(
          (Project p) =>
              p.status != ProjectStatus.completed &&
              p.dueDate != null &&
              p.dueDate!.toLocal().isBefore(today),
        )
        .length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Projects',
          subtitle: 'Track delivery across the team',
          actions: <Widget>[
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(projectsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            _ProjectTemplatesButton(
              onSelected: (ProjectTemplate t) =>
                  _openForm(context, ref, template: t),
            ),
            FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New project'),
            ),
          ],
        ),
        if (projectsAsync.isLoading) const LoadingBar(),
        if (projectsAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorNotice(error: projectsAsync.error!),
          ),
        const SizedBox(height: 20),
        StatCardGrid(
          cards: <Widget>[
            StatCard(
              icon: Icons.folder_rounded,
              color: AppColors.brand,
              label: 'Total projects',
              value: '${projects.length}',
              footer: 'in the workspace',
            ),
            StatCard(
              icon: Icons.bolt_rounded,
              color: AppColors.sky,
              label: 'Active',
              value: '$active',
              footer: 'in progress',
            ),
            StatCard(
              icon: Icons.task_alt_rounded,
              color: AppColors.green,
              label: 'Completed',
              value: '$completed',
              footer: 'delivered',
            ),
            StatCard(
              icon: Icons.donut_large_rounded,
              color: AppColors.teal,
              label: 'Avg. progress',
              value: '${(avg * 100).round()}%',
              progress: avg,
            ),
            StatCard(
              icon: Icons.warning_amber_rounded,
              color: AppColors.rose,
              label: 'Overdue',
              value: '$overdue',
              footer: 'past due date',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (projects.isEmpty && !projectsAsync.isLoading)
          const EmptyState(
            icon: Icons.folder_off_rounded,
            message: 'No projects yet. Create your first one.',
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              final int cols = w >= 1080 ? 3 : (w >= 680 ? 2 : 1);
              const double gap = 16;
              final double cardW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final Project project in projects)
                    SizedBox(
                      width: cardW,
                      child: _ProjectCard(project: project),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
  ProjectTemplate? template,
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        ProjectFormDialog(project: project, template: template),
  );
  if (saved ?? false) {
    ref.invalidate(projectsProvider);
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusPill(
                label: project.status.label,
                color: project.status.color,
              ),
              const SizedBox(width: 6),
              _HealthBadge(project: project),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Project actions',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (String v) => _onAction(context, ref, v),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  if (ref.watch(authControllerProvider).asData?.value.isAdmin ??
                      false)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              project.description.isEmpty
                  ? 'No description'
                  : project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                '${project.doneTasks}/${project.totalTasks} tasks',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${(project.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: project.status.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              if (project.memberNames.isEmpty)
                Text(
                  'No members',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                _AvatarStack(names: project.memberNames),
              const Spacer(),
              if (project.dueDate != null) _DueChip(due: project.dueDate!),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      await _openForm(context, ref, project: project);
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text('"${project.name}" will be permanently removed.'),
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
    );
    if (!(confirm ?? false)) {
      return;
    }
    try {
      await ref.read(projectsRepositoryProvider).delete(project.id);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

/// A "From template" menu shown beside "New project" when templates exist.
class _ProjectTemplatesButton extends ConsumerWidget {
  const _ProjectTemplatesButton({required this.onSelected});
  final ValueChanged<ProjectTemplate> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ProjectTemplate> templates =
        ref.watch(projectTemplatesProvider).asData?.value ??
        const <ProjectTemplate>[];
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<ProjectTemplate>(
      tooltip: 'New from template',
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ProjectTemplate>>[
        for (final ProjectTemplate t in templates)
          PopupMenuItem<ProjectTemplate>(value: t, child: Text(t.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bookmark_outline, size: 18),
            SizedBox(width: 8),
            Text('From template'),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A schedule-health chip (On track / At risk / Overdue) for an open project.
class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    if (project.status == ProjectStatus.completed || project.dueDate == null) {
      return const SizedBox.shrink();
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime due = project.dueDate!.toLocal();
    final String label;
    final Color color;
    if (due.isBefore(today)) {
      label = 'Overdue';
      color = AppColors.rose;
    } else if (due.difference(today).inDays <= 7 && project.progress < 0.9) {
      label = 'At risk';
      color = AppColors.amber;
    } else {
      label = 'On track';
      color = AppColors.teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = names.take(3).toList();
    final int extra = names.length - shown.length;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int count = shown.length + (extra > 0 ? 1 : 0);
    final double width = count == 0 ? 0 : (count - 1) * 20.0 + 30;
    return SizedBox(
      height: 30,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: UserAvatar(name: shown[i], radius: 13),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 20.0,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due});
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final bool overdue = due.isBefore(today);
    final Color color = overdue ? AppColors.rose : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.event_rounded, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          shortDate(due),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
