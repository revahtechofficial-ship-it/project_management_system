import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/chart_legend.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/task_status_chart.dart';
import '../../core/widgets/weekly_activity_chart.dart';
import '../../data/models/favorite.dart';
import '../../data/models/reminder.dart';
import '../../data/models/task.dart';
import '../../providers/auth_provider.dart';
import '../favorites/providers/favorites_providers.dart';
import '../reminders/providers/reminders_providers.dart';
import '../reminders/widgets/reminder_dialog.dart';
import '../tasks/providers/tasks_providers.dart';

/// The home dashboard: greeting, KPI cards, activity charts and live task
/// lists. Real numbers come from [tasksProvider]; everything degrades
/// gracefully while that future is loading (AGENTS.md §1 feature page).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasksAsync = ref.watch(tasksProvider);
    final List<Task> tasks = tasksAsync.asData?.value ?? const <Task>[];
    final String name =
        ref.watch(authControllerProvider).asData?.value.user?.name ?? '';
    final _Metrics metrics = _Metrics.from(tasks);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        _GreetingHeader(name: name),
        if (tasksAsync.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (tasksAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _ErrorNotice(error: tasksAsync.error!),
          ),
        const SizedBox(height: 20),
        _KpiSection(metrics: metrics),
        const SizedBox(height: 20),
        const _QuickAccessSection(),
        const SizedBox(height: 20),
        _ChartsSection(metrics: metrics),
        const SizedBox(height: 20),
        _ListsSection(metrics: metrics),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A two-up row of Favorites and upcoming Reminders for quick access.
class _QuickAccessSection extends ConsumerWidget {
  const _QuickAccessSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Favorite> favorites =
        ref.watch(favoritesProvider).asData?.value ?? const <Favorite>[];
    final List<Reminder> reminders =
        (ref.watch(remindersProvider).asData?.value ?? const <Reminder>[])
            .where((Reminder r) => !r.sent)
            .toList(growable: false);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth >= 720;
        final Widget favCard = _FavoritesCard(favorites: favorites);
        final Widget remCard = _RemindersCard(reminders: reminders);
        if (!wide) {
          return Column(
            children: <Widget>[favCard, const SizedBox(height: 16), remCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: favCard),
            const SizedBox(width: 16),
            Expanded(child: remCard),
          ],
        );
      },
    );
  }
}

class _FavoritesCard extends StatelessWidget {
  const _FavoritesCard({required this.favorites});

  final List<Favorite> favorites;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: 'Favorites',
      child: favorites.isEmpty
          ? Text(
              'Star tasks, projects or pages to pin them here.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (final Favorite f in favorites.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.star,
                      color: AppColors.amber,
                      size: 20,
                    ),
                    title: Text(
                      f.label.isEmpty ? f.kind : f.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.go(f.route.isEmpty ? '/' : f.route),
                  ),
              ],
            ),
    );
  }
}

class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.reminders});

  final List<Reminder> reminders;

  static String _remindLabel(DateTime d) {
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${shortDate(d)} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: 'Reminders',
      trailing: TextButton.icon(
        onPressed: () => showReminderDialog(context),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
      ),
      child: reminders.isEmpty
          ? Text(
              'No reminders set. Add one to get a nudge later.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (final Reminder r in reminders.take(6))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                    ),
                    title: Text(
                      r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_remindLabel(r.remindAt.toLocal())),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        await ref
                            .read(remindersRepositoryProvider)
                            .delete(r.id);
                        ref.invalidate(remindersProvider);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String who = name.isEmpty ? '' : ', ${name.split(' ').first}';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${_greeting()}$who 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              formatLongDate(DateTime.now()),
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => GoRouter.of(context).go('/tasks'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New task'),
        ),
      ],
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    return StatCardGrid(
      cards: <Widget>[
        StatCard(
          icon: Icons.list_alt_rounded,
          color: AppColors.brand,
          label: 'Total tasks',
          value: '${metrics.total}',
          footer: 'across all projects',
        ),
        StatCard(
          icon: Icons.check_circle_rounded,
          color: AppColors.green,
          label: 'Completed',
          value: '${metrics.completed}',
          footer: 'done so far',
        ),
        StatCard(
          icon: Icons.timelapse_rounded,
          color: AppColors.orange,
          label: 'In progress',
          value: '${metrics.pending}',
          footer: 'still open',
        ),
        StatCard(
          icon: Icons.donut_large_rounded,
          color: AppColors.sky,
          label: 'Completion rate',
          value: '${metrics.completionRate}%',
          progress: metrics.completionRate / 100,
        ),
      ],
    );
  }
}

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final Widget weekly = DashboardCard(
      title: 'Weekly activity',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 220,
            child: WeeklyActivityChart(
              days: metrics.days,
              created: metrics.created,
              completed: metrics.done,
            ),
          ),
          const SizedBox(height: 8),
          const ChartLegend(
            items: <LegendItem>[
              LegendItem(AppColors.brand, 'Created'),
              LegendItem(AppColors.teal, 'Completed'),
            ],
          ),
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
              completed: metrics.completed,
              pending: metrics.pending,
            ),
          ),
          const SizedBox(height: 8),
          const ChartLegend(
            items: <LegendItem>[
              LegendItem(AppColors.teal, 'Completed'),
              LegendItem(AppColors.brand, 'Pending'),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: <Widget>[weekly, const SizedBox(height: 16), status],
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
    );
  }
}

class _ListsSection extends StatelessWidget {
  const _ListsSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final Widget myTasks = DashboardCard(
      title: 'My open tasks',
      trailing: TextButton(
        onPressed: () => GoRouter.of(context).go('/tasks'),
        child: const Text('View all'),
      ),
      child: _MyTasksList(tasks: metrics.myTasks),
    );

    final Widget recent = DashboardCard(
      title: 'Recent activity',
      child: _RecentActivity(tasks: metrics.recent),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: <Widget>[myTasks, const SizedBox(height: 16), recent],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: myTasks),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: recent),
          ],
        );
      },
    );
  }
}

class _MyTasksList extends StatelessWidget {
  const _MyTasksList({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.celebration_rounded,
        message: "You're all caught up — no open tasks.",
      );
    }
    final List<Task> top = tasks.take(5).toList();
    return Column(
      children: <Widget>[for (final Task task in top) _MyTaskTile(task: task)],
    );
  }
}

class _MyTaskTile extends ConsumerWidget {
  const _MyTaskTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            height: 26,
            child: Checkbox(
              value: task.done,
              onChanged: (bool? value) async {
                await ref
                    .read(tasksRepositoryProvider)
                    .setDone(task.id, done: value ?? false);
                ref.invalidate(tasksProvider);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(task.updatedAt),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        message: 'No recent activity yet.',
      );
    }
    final List<Task> top = tasks.take(6).toList();
    return Column(
      children: <Widget>[
        for (final Task task in top) _ActivityTile(task: task),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool created = task.createdAt.isAtSameMomentAs(task.updatedAt);
    final (IconData icon, Color color, String verb) = task.done
        ? (Icons.check_circle_rounded, AppColors.green, 'Completed')
        : created
        ? (Icons.add_circle_rounded, AppColors.brand, 'Created')
        : (Icons.edit_rounded, AppColors.orange, 'Updated');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <InlineSpan>[
                  TextSpan(text: '$verb '),
                  TextSpan(
                    text: task.title.isEmpty ? 'a task' : task.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(task.updatedAt),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Couldn\'t load tasks: $error',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Derived dashboard view-model. Feature-scoped (not an API DTO), so it stays
/// here rather than in `data/models`.
class _Metrics {
  const _Metrics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.completionRate,
    required this.days,
    required this.created,
    required this.done,
    required this.myTasks,
    required this.recent,
  });

  final int total;
  final int completed;
  final int pending;
  final int completionRate;
  final List<String> days;
  final List<double> created;
  final List<double> done;
  final List<Task> myTasks;
  final List<Task> recent;

  factory _Metrics.from(List<Task> tasks) {
    final int completed = tasks.where((Task t) => t.done).length;
    final int total = tasks.length;
    final int pending = total - completed;
    final int rate = total == 0 ? 0 : ((completed / total) * 100).round();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<String> days = <String>[];
    final List<double> created = <double>[];
    final List<double> done = <double>[];
    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      days.add(weekdayShort(day.weekday));
      created.add(
        tasks
            .where((Task t) => sameDay(t.createdAt.toLocal(), day))
            .length
            .toDouble(),
      );
      done.add(
        tasks
            .where((Task t) => t.done && sameDay(t.updatedAt.toLocal(), day))
            .length
            .toDouble(),
      );
    }

    final List<Task> myTasks = tasks.where((Task t) => !t.done).toList()
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));
    final List<Task> recent = <Task>[...tasks]
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));

    return _Metrics(
      total: total,
      completed: completed,
      pending: pending,
      completionRate: rate,
      days: days,
      created: created,
      done: done,
      myTasks: myTasks,
      recent: recent,
    );
  }
}

String _greeting() {
  final int h = DateTime.now().hour;
  if (h < 12) {
    return 'Good morning';
  }
  if (h < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
}
