import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/chart_legend.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/skeleton.dart';
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

    final bool firstLoad = tasksAsync.isLoading && !tasksAsync.hasValue;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        _GreetingHeader(name: name),
        if (tasksAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _ErrorNotice(error: tasksAsync.error!),
          ),
        const SizedBox(height: 20),
        if (firstLoad)
          const _DashboardSkeleton()
        else ...<Widget>[
          _KpiSection(metrics: metrics),
          const SizedBox(height: 20),
          const _QuickAccessSection(),
          const SizedBox(height: 20),
          _ChartsSection(metrics: metrics),
          const SizedBox(height: 20),
          _ListsSection(metrics: metrics),
          const SizedBox(height: 20),
          _SecondaryListsSection(metrics: metrics),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// A two-up row of Favorites and upcoming Reminders for quick access.
class _QuickAccessSection extends ConsumerWidget {
  const _QuickAccessSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Favorite>> favAsync = ref.watch(favoritesProvider);
    final AsyncValue<List<Reminder>> remAsync = ref.watch(remindersProvider);
    final List<Favorite> favorites =
        favAsync.asData?.value ?? const <Favorite>[];
    final List<Reminder> reminders =
        (remAsync.asData?.value ?? const <Reminder>[])
            .where((Reminder r) => !r.sent)
            .toList(growable: false);
    final bool favLoading = favAsync.isLoading && !favAsync.hasValue;
    final bool remLoading = remAsync.isLoading && !remAsync.hasValue;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth >= 720;
        final Widget favCard =
            _FavoritesCard(favorites: favorites, loading: favLoading);
        final Widget remCard =
            _RemindersCard(reminders: reminders, loading: remLoading);
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
  const _FavoritesCard({required this.favorites, this.loading = false});

  final List<Favorite> favorites;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Favorites',
      child: loading
          ? const SkeletonLines(lines: 3)
          : favorites.isEmpty
          ? const _EmptyState(
              icon: Icons.star_border_rounded,
              message: 'Star tasks, projects or pages to pin them here.',
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
  const _RemindersCard({required this.reminders, this.loading = false});

  final List<Reminder> reminders;
  final bool loading;

  static String _remindLabel(DateTime d) {
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${shortDate(d)} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardCard(
      title: 'Reminders',
      trailing: TextButton.icon(
        onPressed: () => showReminderDialog(context),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
      ),
      child: loading
          ? const SkeletonLines(lines: 3)
          : reminders.isEmpty
          ? const _EmptyState(
              icon: Icons.notifications_none_rounded,
              message: 'No reminders yet — add one to get a nudge later.',
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
        const _QuickAddButton(),
      ],
    );
  }
}

/// A primary "Quick add" control that opens a menu to create a task, project,
/// page or reminder — replacing the lone "New task" button.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Quick add',
      position: PopupMenuPosition.under,
      onSelected: (String v) {
        switch (v) {
          case 'task':
            GoRouter.of(context).go('/tasks');
          case 'project':
            GoRouter.of(context).go('/projects');
          case 'page':
            GoRouter.of(context).go('/pages');
          case 'reminder':
            showReminderDialog(context);
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'task',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline),
            title: Text('New task'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'project',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.folder_outlined),
            title: Text('New project'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'page',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined),
            title: Text('New page'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reminder',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Set reminder'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient(
            Theme.of(context).colorScheme.primary,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.3,
                  ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Quick add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    void openTasks() => GoRouter.of(context).go('/tasks');
    return StatCardGrid(
      cards: <Widget>[
        StatCard(
          icon: Icons.list_alt_rounded,
          color: AppColors.brand,
          label: 'Total tasks',
          value: '${metrics.total}',
          footer: 'across all projects',
          trend: metrics.createdThisWeek > 0
              ? '+${metrics.createdThisWeek} this week'
              : null,
          onTap: openTasks,
        ),
        StatCard(
          icon: Icons.check_circle_rounded,
          color: AppColors.green,
          label: 'Completed',
          value: '${metrics.completed}',
          footer: 'done so far',
          trend: metrics.completedThisWeek > 0
              ? '+${metrics.completedThisWeek} this week'
              : null,
          onTap: openTasks,
        ),
        StatCard(
          icon: Icons.timelapse_rounded,
          color: AppColors.orange,
          label: 'In progress',
          value: '${metrics.pending}',
          footer: 'still open',
          onTap: openTasks,
        ),
        StatCard(
          icon: Icons.donut_large_rounded,
          color: AppColors.sky,
          label: 'Completion rate',
          value: '${metrics.completionRate}%',
          progress: metrics.completionRate / 100,
          onTap: () => GoRouter.of(context).go('/reports'),
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
    final bool hasActivity =
        metrics.created.any((double d) => d > 0) ||
        metrics.done.any((double d) => d > 0);
    final bool hasTasks = metrics.total > 0;

    final Widget weekly = DashboardCard(
      title: 'Weekly activity',
      child: hasActivity
          ? Column(
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
            )
          : const _ChartPlaceholder(
              icon: Icons.show_chart_rounded,
              message: 'No activity in the last 7 days.\n'
                  'Create or complete a task to see trends here.',
            ),
    );

    final Widget status = DashboardCard(
      title: 'Task status',
      child: hasTasks
          ? Column(
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
            )
          : const _ChartPlaceholder(
              icon: Icons.donut_large_rounded,
              message: 'No tasks yet.\n'
                  'Add your first task to track completion.',
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

/// A second content row — upcoming deadlines and the busiest projects — so the
/// dashboard fills the page instead of trailing off into empty space.
class _SecondaryListsSection extends StatelessWidget {
  const _SecondaryListsSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final Widget deadlines = DashboardCard(
      title: 'Upcoming deadlines',
      trailing: TextButton(
        onPressed: () => GoRouter.of(context).go('/tasks'),
        child: const Text('View all'),
      ),
      child: metrics.upcoming.isEmpty
          ? const _EmptyState(
              icon: Icons.event_available_rounded,
              message: 'No due dates set. Add one to see deadlines here.',
            )
          : Column(
              children: <Widget>[
                for (final Task t in metrics.upcoming.take(5))
                  _DeadlineTile(task: t),
              ],
            ),
    );

    final Widget projects = DashboardCard(
      title: 'Active projects',
      trailing: TextButton(
        onPressed: () => GoRouter.of(context).go('/projects'),
        child: const Text('View all'),
      ),
      child: metrics.projectLoad.isEmpty
          ? const _EmptyState(
              icon: Icons.folder_open_rounded,
              message: 'No open work grouped by project yet.',
            )
          : Column(
              children: <Widget>[
                for (final ({String name, int open}) p
                    in metrics.projectLoad.take(5))
                  _ProjectLoadTile(name: p.name, open: p.open),
              ],
            ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: <Widget>[deadlines, const SizedBox(height: 16), projects],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: deadlines),
            const SizedBox(width: 16),
            Expanded(child: projects),
          ],
        );
      },
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime due = task.dueDate!.toLocal();
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final bool overdue = due.isBefore(todayStart);
    final Color tone = overdue ? AppColors.rose : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title.isEmpty ? 'Untitled task' : task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            shortDate(due),
            style: TextStyle(
              fontSize: 12,
              fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectLoadTile extends StatelessWidget {
  const _ProjectLoadTile({required this.name, required this.open});
  final String name;
  final int open;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.folder_outlined, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(
            '$open open',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
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

/// A fixed-height empty state for a chart card, so the card keeps a chart-like
/// footprint (and aligns with its neighbour) when there's no data to plot.
class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
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

/// Shimmering stand-in for the whole dashboard on first load, so the page
/// never flashes empty (or a transient provider error) before tasks arrive.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StatCardGrid(
          cards: <Widget>[for (int i = 0; i < 4; i++) const _StatSkeleton()],
        ),
        const SizedBox(height: 20),
        const _CardSkeleton(blockHeight: 240),
        const SizedBox(height: 16),
        const _CardSkeleton(lines: 4),
      ],
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return const GlassSurface(
      borderRadius: 18,
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Skeleton(width: 42, height: 42, radius: 12),
            SizedBox(height: 14),
            Skeleton(width: 64, height: 26),
            SizedBox(height: 8),
            Skeleton(width: 96, height: 13),
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({this.lines = 3, this.blockHeight});
  final int lines;
  final double? blockHeight;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Skeleton(width: 140, height: 16),
          const SizedBox(height: 16),
          if (blockHeight != null)
            Skeleton(width: double.infinity, height: blockHeight!, radius: 12)
          else
            SkeletonLines(lines: lines),
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
    required this.createdThisWeek,
    required this.completedThisWeek,
    required this.myTasks,
    required this.recent,
    required this.upcoming,
    required this.projectLoad,
  });

  final int total;
  final int completed;
  final int pending;
  final int completionRate;
  final List<String> days;
  final List<double> created;
  final List<double> done;
  final int createdThisWeek;
  final int completedThisWeek;
  final List<Task> myTasks;
  final List<Task> recent;
  final List<Task> upcoming;
  final List<({String name, int open})> projectLoad;

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

    final int createdThisWeek =
        created.fold(0, (int a, double b) => a + b.toInt());
    final int completedThisWeek =
        done.fold(0, (int a, double b) => a + b.toInt());

    final List<Task> myTasks = tasks.where((Task t) => !t.done).toList()
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));
    final List<Task> recent = <Task>[...tasks]
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));

    final List<Task> upcoming =
        tasks
            .where((Task t) => !t.done && t.dueDate != null)
            .toList()
          ..sort((Task a, Task b) => a.dueDate!.compareTo(b.dueDate!));

    final Map<String, int> load = <String, int>{};
    for (final Task t in tasks.where((Task t) => !t.done)) {
      final String name = (t.projectName ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      load[name] = (load[name] ?? 0) + 1;
    }
    final List<({String name, int open})> projectLoad = load.entries
        .map((MapEntry<String, int> e) => (name: e.key, open: e.value))
        .toList()
      ..sort((({String name, int open}) a, ({String name, int open}) b) =>
          b.open.compareTo(a.open));

    return _Metrics(
      total: total,
      completed: completed,
      pending: pending,
      completionRate: rate,
      days: days,
      created: created,
      done: done,
      createdThisWeek: createdThisWeek,
      completedThisWeek: completedThisWeek,
      myTasks: myTasks,
      recent: recent,
      upcoming: upcoming,
      projectLoad: projectLoad,
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
