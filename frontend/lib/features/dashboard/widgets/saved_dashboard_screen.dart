import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/dashboard_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/task_status_chart.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/enums/dashboard_widget.dart';
import '../../../data/models/project.dart';
import '../../../data/models/saved_dashboard.dart';
import '../../../data/models/task.dart';
import '../../../data/models/team_member.dart';
import '../../projects/providers/projects_providers.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/dashboards_providers.dart';
import 'dashboard_builder_dialog.dart';

/// Renders a saved dashboard from live task/team/project data, with edit and
/// delete for its owner. Pushed via [Navigator] (AGENTS.md §9).
class SavedDashboardScreen extends ConsumerStatefulWidget {
  const SavedDashboardScreen({super.key, required this.dashboard});

  final SavedDashboard dashboard;

  @override
  ConsumerState<SavedDashboardScreen> createState() =>
      _SavedDashboardScreenState();
}

class _SavedDashboardScreenState extends ConsumerState<SavedDashboardScreen> {
  late SavedDashboard _dashboard = widget.dashboard;

  Future<void> _edit() async {
    final SavedDashboard? updated = await showDashboardBuilder(
      context,
      existing: _dashboard,
    );
    if (updated != null && mounted) {
      setState(() => _dashboard = updated);
      ref.invalidate(savedDashboardsProvider);
    }
  }

  Future<void> _delete() async {
    final bool ok = await confirmDelete(
      context,
      what: '"${_dashboard.name}"',
      message: 'This cannot be undone.',
    );
    if (!ok) {
      return;
    }
    await ref.read(dashboardsRepositoryProvider).delete(_dashboard.id);
    ref.invalidate(savedDashboardsProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final List<TeamMember> team =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final _Metrics m = _compute(tasks, team, projects);

    final List<DashboardWidgetKind> kinds = _dashboard.widgets
        .map(DashboardWidgetKind.byKey)
        .whereType<DashboardWidgetKind>()
        .toList(growable: false);
    final List<DashboardWidgetKind> tiles = kinds
        .where((DashboardWidgetKind k) => !k.isWide)
        .toList(growable: false);
    final List<DashboardWidgetKind> wides = kinds
        .where((DashboardWidgetKind k) => k.isWide)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_dashboard.name.isEmpty ? 'Dashboard' : _dashboard.name),
        actions: <Widget>[
          if (_dashboard.canManage) ...<Widget>[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: kinds.isEmpty
          ? const Center(child: Text('This dashboard has no widgets yet.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                if (tiles.isNotEmpty)
                  StatCardGrid(
                    cards: <Widget>[
                      for (final DashboardWidgetKind k in tiles)
                        _metricCard(k, m),
                    ],
                  ),
                for (final DashboardWidgetKind k in wides) ...<Widget>[
                  const SizedBox(height: 16),
                  _wideWidget(k, m, tasks, team),
                ],
              ],
            ),
    );
  }

  Widget _metricCard(DashboardWidgetKind k, _Metrics m) {
    final (String value, String? footer, double? progress) = switch (k) {
      DashboardWidgetKind.totalTasks => (
        '${m.total}',
        'across all projects',
        null,
      ),
      DashboardWidgetKind.completed => ('${m.completed}', 'done so far', null),
      DashboardWidgetKind.inProgress => ('${m.inProgress}', 'still open', null),
      DashboardWidgetKind.overdue => ('${m.overdue}', 'past due', null),
      DashboardWidgetKind.completionRate => (
        '${(m.completionRate * 100).round()}%',
        'completion',
        m.completionRate,
      ),
      DashboardWidgetKind.storyPoints => ('${m.points}', 'open points', null),
      DashboardWidgetKind.teamSize => ('${m.teamSize}', 'members', null),
      DashboardWidgetKind.projectCount => (
        '${m.projectCount}',
        'projects',
        null,
      ),
      _ => ('', null, null),
    };
    return StatCard(
      icon: k.icon,
      color: k.color,
      label: k.label,
      value: value,
      footer: footer,
      progress: progress,
    );
  }

  Widget _wideWidget(
    DashboardWidgetKind k,
    _Metrics m,
    List<Task> tasks,
    List<TeamMember> team,
  ) {
    return switch (k) {
      DashboardWidgetKind.taskStatus => DashboardCard(
        title: 'Task status',
        child: SizedBox(
          height: 220,
          child: TaskStatusChart(completed: m.completed, pending: m.inProgress),
        ),
      ),
      DashboardWidgetKind.teamWorkload => DashboardCard(
        title: 'Team workload',
        child: _Workload(tasks: tasks),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Metrics {
  const _Metrics({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.overdue,
    required this.points,
    required this.teamSize,
    required this.projectCount,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int overdue;
  final int points;
  final int teamSize;
  final int projectCount;

  double get completionRate => total == 0 ? 0 : completed / total;
}

_Metrics _compute(
  List<Task> tasks,
  List<TeamMember> team,
  List<Project> projects,
) {
  final DateTime now = DateTime.now();
  int total = 0, done = 0, open = 0, overdue = 0, points = 0;
  for (final Task t in tasks) {
    if (t.parentId != null) {
      continue;
    }
    total++;
    points += t.points;
    if (t.done) {
      done++;
    } else {
      open++;
      if (t.dueDate != null && t.dueDate!.toLocal().isBefore(now)) {
        overdue++;
      }
    }
  }
  return _Metrics(
    total: total,
    completed: done,
    inProgress: open,
    overdue: overdue,
    points: points,
    teamSize: team.length,
    projectCount: projects.length,
  );
}

/// A compact per-assignee open-task count, derived from the task list.
class _Workload extends StatelessWidget {
  const _Workload({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, int> byName = <String, int>{};
    for (final Task t in tasks) {
      if (t.done || t.parentId != null) {
        continue;
      }
      final List<String> names = t.assigneeNames.isEmpty
          ? const <String>['Unassigned']
          : t.assigneeNames;
      for (final String n in names) {
        byName[n] = (byName[n] ?? 0) + 1;
      }
    }
    if (byName.isEmpty) {
      return Text(
        'No open work to chart yet.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    final List<MapEntry<String, int>> rows = byName.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    final int max = rows.first.value;
    return Column(
      children: <Widget>[
        for (final MapEntry<String, int> e in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                if (e.key == 'Unassigned')
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person_off_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  UserAvatar(name: e.key, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              e.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : e.value / max,
                          minHeight: 7,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.violet,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
