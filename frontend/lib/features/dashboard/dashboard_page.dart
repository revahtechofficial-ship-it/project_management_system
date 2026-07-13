import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/back_to_top.dart';
import '../../core/widgets/chart_legend.dart';
import '../../core/widgets/contribution_heatmap.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/donut_breakdown.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/task_status_chart.dart';
import '../../core/widgets/weekly_activity_chart.dart';
import '../../data/enums/task_priority.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/favorite.dart';
import '../../data/models/reminder.dart';
import '../../data/models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../favorites/providers/favorites_providers.dart';
import '../onboarding/widgets/onboarding_tour.dart';
import '../reminders/providers/reminders_providers.dart';
import '../reminders/widgets/reminder_dialog.dart';
import '../tasks/providers/tasks_providers.dart';
import '../patro/widgets/patro_today_card.dart';

/// The home dashboard: greeting, KPI cards, activity charts and live task
/// lists. Real numbers come from [tasksProvider]; everything degrades
/// gracefully while that future is loading (AGENTS.md §1 feature page).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasksAsync = ref.watch(tasksProvider);
    final List<Task> tasks = tasksAsync.asData?.value ?? const <Task>[];
    final AuthUser? user = ref.watch(authControllerProvider).asData?.value.user;
    final _Metrics metrics = _Metrics.from(tasks);

    // Show the first-run tour once the "seen" flag has loaded as false.
    if (ref.watch(onboardingProvider) == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) {
          return;
        }
        await ref.read(onboardingProvider.notifier).markSeen();
        if (context.mounted) {
          await showOnboardingTour(context);
        }
      });
    }

    final bool firstLoad = tasksAsync.isLoading && !tasksAsync.hasValue;
    return BackToTop(
      builder: (ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _GreetingHeader(name: user?.name ?? '', streak: metrics.streak),
          if (tasksAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ErrorNotice(error: tasksAsync.error!),
            ),
          const SizedBox(height: 20),
          if (firstLoad)
            const _DashboardSkeleton()
          else ...<Widget>[
            const _QuickActionsRow(),
            const SizedBox(height: 16),
            const PatroTodayCard(),
            const SizedBox(height: 16),
            _SummaryBand(metrics: metrics),
            if (user != null && _profileCompletion(user) < 1.0) ...<Widget>[
              const SizedBox(height: 16),
              _ProfileMeter(user: user),
            ],
            const SizedBox(height: 20),
            _KpiSection(metrics: metrics),
            const SizedBox(height: 20),
            const _QuickAccessSection(),
            const SizedBox(height: 20),
            _ChartsSection(metrics: metrics),
            const SizedBox(height: 20),
            _InsightsSection(metrics: metrics),
            const SizedBox(height: 20),
            _ListsSection(metrics: metrics),
            const SizedBox(height: 20),
            _SecondaryListsSection(metrics: metrics),
            const SizedBox(height: 8),
          ],
        ],
      ),
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
        final Widget favCard = _FavoritesCard(
          favorites: favorites,
          loading: favLoading,
        );
        final Widget remCard = _RemindersCard(
          reminders: reminders,
          loading: remLoading,
        );
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
  const _GreetingHeader({required this.name, this.streak = 0});
  final String name;
  final int streak;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${_greeting()}$who 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (streak >= 2) ...<Widget>[
                  const SizedBox(width: 12),
                  _StreakChip(days: streak),
                ],
              ],
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

/// A "🔥 N-day streak" chip celebrating consecutive days of completions.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '🔥 $days-day streak',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

/// Profile completeness as a 0..1 fraction over the optional profile fields.
double _profileCompletion(AuthUser user) {
  final List<bool> filled = <bool>[
    user.avatarUrl != null && user.avatarUrl!.isNotEmpty,
    user.phone.isNotEmpty,
    user.jobTitle.isNotEmpty,
    user.department.isNotEmpty,
    user.location.isNotEmpty,
    user.bio.isNotEmpty,
  ];
  final int done = filled.where((bool b) => b).length;
  return done / filled.length;
}

/// A row of one-tap shortcuts to create/jump into common areas.
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    const List<({IconData icon, String label, Color color, String route})>
    actions = <({IconData icon, String label, Color color, String route})>[
      (
        icon: Icons.add_task,
        label: 'New task',
        color: AppColors.brand,
        route: '/tasks',
      ),
      (
        icon: Icons.create_new_folder_outlined,
        label: 'New project',
        color: AppColors.teal,
        route: '/projects',
      ),
      (
        icon: Icons.chat_bubble_outline,
        label: 'Message',
        color: AppColors.sky,
        route: '/chat',
      ),
      (
        icon: Icons.auto_awesome,
        label: 'Ask AI',
        color: AppColors.violet,
        route: '/ai',
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = c.maxWidth < 560 ? 2 : 4;
        const double gap = 12;
        final double w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final ({
                  IconData icon,
                  String label,
                  Color color,
                  String route,
                })
                a
                in actions)
              SizedBox(
                width: w,
                child: _QuickActionCard(
                  icon: a.icon,
                  label: a.label,
                  color: a.color,
                  onTap: () => GoRouter.of(context).go(a.route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 14,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim "at a glance" band summarising today's workload.
class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final List<({IconData icon, int value, String label, Color color})> stats =
        <({IconData icon, int value, String label, Color color})>[
          (
            icon: Icons.today_rounded,
            value: metrics.dueToday,
            label: 'due today',
            color: AppColors.brand,
          ),
          (
            icon: Icons.warning_amber_rounded,
            value: metrics.overdue,
            label: 'overdue',
            color: AppColors.rose,
          ),
          (
            icon: Icons.timelapse_rounded,
            value: metrics.pending,
            label: 'in progress',
            color: AppColors.orange,
          ),
          (
            icon: Icons.check_circle_rounded,
            value: metrics.completedThisWeek,
            label: 'done this week',
            color: AppColors.green,
          ),
        ];
    return GlassSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Wrap(
          spacing: 22,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final ({IconData icon, int value, String label, Color color}) s
                in stats)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Text(
                    '${s.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    s.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A profile-completeness meter with a CTA, shown until the profile is full.
class _ProfileMeter extends StatelessWidget {
  const _ProfileMeter({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double pct = _profileCompletion(user);
    return GlassSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(Icons.account_circle_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text(
                        'Complete your profile',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${(pct * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => GoRouter.of(context).go('/profile'),
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
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
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
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
          trend: metrics.createdThisWeek > 0
              ? '+${metrics.createdThisWeek} this week'
              : null,
          spark: metrics.created,
          onTap: openTasks,
        ),
        StatCard(
          icon: Icons.check_circle_rounded,
          color: AppColors.green,
          label: 'Completed',
          value: '${metrics.completed}',
          trend: metrics.completedThisWeek > 0
              ? '+${metrics.completedThisWeek} this week'
              : null,
          spark: metrics.done,
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
              message:
                  'No activity in the last 7 days.\n'
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
              message:
                  'No tasks yet.\n'
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

/// Completion ring, open-by-priority donut and a tasks-created heatmap.
class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final List<DonutSegment> segments = <DonutSegment>[
      for (final TaskPriority p in TaskPriority.values)
        if ((metrics.byPriority[p] ?? 0) > 0)
          DonutSegment(
            label: p.label,
            value: metrics.byPriority[p]!,
            color: p.color,
          ),
    ];

    final Widget completion = DashboardCard(
      title: 'Completion',
      child: SizedBox(
        height: 200,
        child: Center(
          child: ProgressRing(
            value: metrics.completionRate / 100,
            color: AppColors.green,
            size: 150,
            label: '${metrics.completionRate}%',
            caption: 'completed',
          ),
        ),
      ),
    );

    final Widget priority = DashboardCard(
      title: 'Open by priority',
      child: SizedBox(
        height: 200,
        child: segments.isEmpty
            ? const _EmptyState(
                icon: Icons.flag_outlined,
                message: 'No open tasks to prioritise.',
              )
            : Center(
                child: DonutBreakdown(segments: segments, centerLabel: 'open'),
              ),
      ),
    );

    final Widget heatmap = DashboardCard(
      title: 'Tasks created',
      child: metrics.activityByDay.isEmpty
          ? const _ChartPlaceholder(
              icon: Icons.grid_on_rounded,
              message:
                  'No tasks yet.\n'
                  'Create tasks to build up your activity calendar.',
            )
          : ContributionHeatmap(
              counts: metrics.activityByDay,
              anchor: DateTime.now(),
            ),
    );

    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 920) {
              return Column(
                children: <Widget>[
                  completion,
                  const SizedBox(height: 16),
                  priority,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: completion),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: priority),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        heatmap,
      ],
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
    required this.byPriority,
    required this.activityByDay,
    required this.overdue,
    required this.dueToday,
    required this.streak,
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

  /// Open (not-done) task counts per priority, for the priority donut.
  final Map<TaskPriority, int> byPriority;

  /// Tasks created per day, for the contribution heatmap.
  final Map<DateTime, int> activityByDay;

  /// Open tasks past their due date.
  final int overdue;

  /// Open tasks due today.
  final int dueToday;

  /// Consecutive days (ending today, with a one-day grace) that had at least
  /// one task completed.
  final int streak;

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

    final int createdThisWeek = created.fold(
      0,
      (int a, double b) => a + b.toInt(),
    );
    final int completedThisWeek = done.fold(
      0,
      (int a, double b) => a + b.toInt(),
    );

    final List<Task> myTasks = tasks.where((Task t) => !t.done).toList()
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));
    final List<Task> recent = <Task>[...tasks]
      ..sort((Task a, Task b) => b.updatedAt.compareTo(a.updatedAt));

    final List<Task> upcoming =
        tasks.where((Task t) => !t.done && t.dueDate != null).toList()
          ..sort((Task a, Task b) => a.dueDate!.compareTo(b.dueDate!));

    final Map<String, int> load = <String, int>{};
    for (final Task t in tasks.where((Task t) => !t.done)) {
      final String name = (t.projectName ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      load[name] = (load[name] ?? 0) + 1;
    }
    final List<({String name, int open})> projectLoad =
        load.entries
            .map((MapEntry<String, int> e) => (name: e.key, open: e.value))
            .toList()
          ..sort(
            (({String name, int open}) a, ({String name, int open}) b) =>
                b.open.compareTo(a.open),
          );

    // Open tasks by priority (for the donut breakdown).
    final Map<TaskPriority, int> byPriority = <TaskPriority, int>{};
    for (final Task t in tasks.where((Task t) => !t.done)) {
      byPriority[t.priority] = (byPriority[t.priority] ?? 0) + 1;
    }

    // Tasks created per day (for the contribution heatmap).
    final Map<DateTime, int> activityByDay = <DateTime, int>{};
    for (final Task t in tasks) {
      final DateTime d = DateTime(
        t.createdAt.toLocal().year,
        t.createdAt.toLocal().month,
        t.createdAt.toLocal().day,
      );
      activityByDay[d] = (activityByDay[d] ?? 0) + 1;
    }

    final int overdue = tasks
        .where(
          (Task t) =>
              !t.done &&
              t.dueDate != null &&
              t.dueDate!.toLocal().isBefore(today),
        )
        .length;
    final int dueToday = tasks
        .where(
          (Task t) =>
              !t.done &&
              t.dueDate != null &&
              sameDay(t.dueDate!.toLocal(), today),
        )
        .length;

    // Completion streak: consecutive days (with a one-day grace for today)
    // that had at least one task completed.
    final Set<DateTime> doneDays = <DateTime>{
      for (final Task t in tasks)
        if (t.done)
          DateTime(
            t.updatedAt.toLocal().year,
            t.updatedAt.toLocal().month,
            t.updatedAt.toLocal().day,
          ),
    };
    int streak = 0;
    DateTime cursor = today;
    if (!doneDays.contains(today) &&
        doneDays.contains(today.subtract(const Duration(days: 1)))) {
      cursor = today.subtract(const Duration(days: 1));
    }
    while (doneDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

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
      byPriority: byPriority,
      activityByDay: activityByDay,
      overdue: overdue,
      dueToday: dueToday,
      streak: streak,
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
