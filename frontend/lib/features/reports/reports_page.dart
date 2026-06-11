import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/chart_legend.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/productivity_chart.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/task_status_chart.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/weekly_activity_chart.dart';
import '../../data/models/task.dart';
import '../../data/models/team_member.dart';
import '../tasks/providers/tasks_providers.dart';
import '../team/providers/team_providers.dart';

/// Analytics over real task data: productivity trend, weekly activity, status
/// split, and team contributions.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasksAsync = ref.watch(tasksProvider);
    final List<Task> tasks = tasksAsync.asData?.value ?? const <Task>[];
    final List<TeamMember> team =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final _ReportData data = _ReportData.from(tasks);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Reports',
          subtitle: 'Productivity & insights',
          actions: <Widget>[
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(tasksProvider);
                ref.invalidate(teamMembersProvider);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (tasksAsync.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        const SizedBox(height: 20),
        StatCardGrid(
          cards: <Widget>[
            StatCard(
              icon: Icons.list_alt_rounded,
              color: AppColors.brand,
              label: 'Total tasks',
              value: '${data.total}',
              footer: 'all-time',
            ),
            StatCard(
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              label: 'Completed',
              value: '${data.completed}',
              footer: 'done so far',
            ),
            StatCard(
              icon: Icons.donut_large_rounded,
              color: AppColors.sky,
              label: 'Completion rate',
              value: '${data.completionRate}%',
              progress: data.completionRate / 100,
            ),
            StatCard(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              label: 'Done this week',
              value: '${data.completedThisWeek}',
              footer: 'last 7 days',
            ),
          ],
        ),
        const SizedBox(height: 20),
        DashboardCard(
          title: 'Tasks completed — last 14 days',
          child: SizedBox(
            height: 240,
            child: ProductivityChart(
              labels: data.trendLabels,
              values: data.trendValues,
            ),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget weekly = DashboardCard(
              title: 'Weekly activity',
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 220,
                    child: WeeklyActivityChart(
                      days: data.weekDays,
                      created: data.weekCreated,
                      completed: data.weekDone,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ChartLegend(items: <LegendItem>[
                    LegendItem(AppColors.brand, 'Created'),
                    LegendItem(AppColors.teal, 'Completed'),
                  ]),
                ],
              ),
            );
            final Widget status = DashboardCard(
              title: 'Task status',
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 220,
                    child: TaskStatusChart(
                      completed: data.completed,
                      pending: data.pending,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ChartLegend(items: <LegendItem>[
                    LegendItem(AppColors.teal, 'Completed'),
                    LegendItem(AppColors.brand, 'Pending'),
                  ]),
                ],
              ),
            );
            if (constraints.maxWidth < 920) {
              return Column(
                children: <Widget>[
                  weekly,
                  const SizedBox(height: 16),
                  status,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 3, child: weekly),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: status),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        DashboardCard(
          title: 'Top contributors',
          child: _Contributors(team: team),
        ),
      ],
    );
  }
}

class _Contributors extends StatelessWidget {
  const _Contributors({required this.team});
  final List<TeamMember> team;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TeamMember> ranked = <TeamMember>[...team]
      ..sort((TeamMember a, TeamMember b) =>
          b.completedTasks.compareTo(a.completedTasks));
    final List<TeamMember> top = ranked.take(5).toList();
    final int max = top.isEmpty ? 1 : top.first.completedTasks;

    return Column(
      children: <Widget>[
        for (final TeamMember m in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                UserAvatar(name: m.name, radius: 16),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : m.completedTasks / max,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: m.role.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${m.completedTasks}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Report series derived from the real task list.
class _ReportData {
  const _ReportData({
    required this.total,
    required this.completed,
    required this.pending,
    required this.completionRate,
    required this.completedThisWeek,
    required this.trendLabels,
    required this.trendValues,
    required this.weekDays,
    required this.weekCreated,
    required this.weekDone,
  });

  final int total;
  final int completed;
  final int pending;
  final int completionRate;
  final int completedThisWeek;
  final List<String> trendLabels;
  final List<double> trendValues;
  final List<String> weekDays;
  final List<double> weekCreated;
  final List<double> weekDone;

  factory _ReportData.from(List<Task> tasks) {
    final int completed = tasks.where((Task t) => t.done).length;
    final int total = tasks.length;
    final int pending = total - completed;
    final int rate = total == 0 ? 0 : ((completed / total) * 100).round();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<String> trendLabels = <String>[];
    final List<double> trendValues = <double>[];
    for (int i = 13; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      trendLabels.add('${day.day}');
      trendValues.add(tasks
          .where((Task t) => t.done && sameDay(t.updatedAt.toLocal(), day))
          .length
          .toDouble());
    }

    final List<String> weekDays = <String>[];
    final List<double> weekCreated = <double>[];
    final List<double> weekDone = <double>[];
    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      weekDays.add(weekdayShort(day.weekday));
      weekCreated.add(tasks
          .where((Task t) => sameDay(t.createdAt.toLocal(), day))
          .length
          .toDouble());
      weekDone.add(tasks
          .where((Task t) => t.done && sameDay(t.updatedAt.toLocal(), day))
          .length
          .toDouble());
    }
    final double thisWeek =
        weekDone.fold<double>(0, (double s, double v) => s + v);

    return _ReportData(
      total: total,
      completed: completed,
      pending: pending,
      completionRate: rate,
      completedThisWeek: thisWeek.round(),
      trendLabels: trendLabels,
      trendValues: trendValues,
      weekDays: weekDays,
      weekCreated: weekCreated,
      weekDone: weekDone,
    );
  }
}
