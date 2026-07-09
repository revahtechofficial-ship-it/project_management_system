import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/enums/project_status.dart';
import '../../data/models/project.dart';
import '../projects/providers/projects_providers.dart';

/// A now / next / later roadmap across all projects, bucketed by target date.
/// Read-only and derived from the live project list (AGENTS.md §1 feature page).
class RoadmapPage extends ConsumerWidget {
  const RoadmapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> async = ref.watch(projectsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PageHeader(
            title: 'Roadmap',
            subtitle: 'Now, next and later across every project',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(projectsProvider),
              ),
              data: (List<Project> projects) => _Board(projects: projects),
            ),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.projects});
  final List<Project> projects;

  static int _byDue(Project a, Project b) {
    if (a.dueDate == null && b.dueDate == null) return 0;
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime in30 = today.add(const Duration(days: 30));
    final DateTime in90 = today.add(const Duration(days: 90));

    final List<Project> nowB = <Project>[];
    final List<Project> nextB = <Project>[];
    final List<Project> laterB = <Project>[];
    final List<Project> shipped = <Project>[];
    for (final Project p in projects) {
      if (p.status == ProjectStatus.completed) {
        shipped.add(p);
        continue;
      }
      final DateTime? d = p.dueDate?.toLocal();
      if (d == null) {
        laterB.add(p);
      } else if (!d.isAfter(in30)) {
        nowB.add(p);
      } else if (!d.isAfter(in90)) {
        nextB.add(p);
      } else {
        laterB.add(p);
      }
    }
    for (final List<Project> b in <List<Project>>[nowB, nextB, laterB]) {
      b.sort(_byDue);
    }

    if (projects.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: 'No projects yet',
        message:
            'Create projects with target dates to see them on the '
            'roadmap.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Column(
            title: 'Now',
            subtitle: 'Overdue · next 30 days',
            color: AppColors.rose,
            projects: nowB,
          ),
          _Column(
            title: 'Next',
            subtitle: '1–3 months',
            color: AppColors.brand,
            projects: nextB,
          ),
          _Column(
            title: 'Later',
            subtitle: 'Beyond · undated',
            color: AppColors.slate,
            projects: laterB,
          ),
          _Column(
            title: 'Shipped',
            subtitle: 'Completed',
            color: AppColors.green,
            projects: shipped,
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.projects,
  });
  final String title;
  final String subtitle;
  final Color color;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${projects.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, bottom: 10),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: projects.isEmpty
                  ? Center(
                      child: Text(
                        '—',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        for (final Project p in projects)
                          _ProjectCard(project: p),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool overdue =
        project.dueDate != null &&
        project.status != ProjectStatus.completed &&
        project.dueDate!.toLocal().isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => GoRouter.of(context).go('/projects'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                project.name.isEmpty ? 'Project' : project.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  StatusPill(
                    label: project.status.label,
                    color: project.status.color,
                  ),
                  const Spacer(),
                  if (project.dueDate != null)
                    Text(
                      shortDate(project.dueDate!.toLocal()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: overdue
                            ? AppColors.rose
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: project.progress,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  color: project.status.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${project.doneTasks}/${project.totalTasks} tasks',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
