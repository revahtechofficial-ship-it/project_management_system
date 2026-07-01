import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/back_to_top.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sticky_header.dart';
import '../../data/models/feed_activity.dart';
import 'providers/activity_providers.dart';

/// Collaboration History: a workspace-wide timeline of recent task activity
/// (created, status changes, comments, edits) across the whole team
/// (AGENTS.md §1 feature page).
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FeedActivity>> async = ref.watch(activityFeedProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Activity',
            subtitle: 'Workspace collaboration history',
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(activityFeedProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(activityFeedProvider),
              ),
              data: (List<FeedActivity> items) => _Feed(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feed extends StatefulWidget {
  const _Feed({required this.items});

  final List<FeedActivity> items;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  String _filter = 'all';

  static const List<(String, String)> _filters = <(String, String)>[
    ('all', 'All'),
    ('comment', 'Comments'),
    ('status', 'Status'),
    ('created', 'Created'),
    ('updated', 'Edits'),
  ];

  bool _matches(FeedActivity a) {
    switch (_filter) {
      case 'all':
        return true;
      case 'status':
        return a.action == 'status' ||
            a.action == 'completed' ||
            a.action == 'reopened';
      default:
        return a.action == _filter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<FeedActivity> filtered = widget.items
        .where(_matches)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final (String key, String label) in _filters)
              ChoiceChip(
                label: Text(label),
                selected: _filter == key,
                onSelected: (_) => setState(() => _filter = key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  message: 'No activity to show yet.',
                )
              : _GroupedList(items: filtered),
        ),
      ],
    );
  }
}

/// The filtered activity grouped under day headers (Today / Yesterday / date).
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items});

  final List<FeedActivity> items;

  static String _dayLabel(DateTime d, DateTime today) {
    final DateTime day = DateTime(d.year, d.month, d.day);
    final int diff = today.difference(day).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    return shortDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<StickySection> sections = <StickySection>[];
    for (final FeedActivity a in items) {
      final String label = _dayLabel(a.createdAt.toLocal(), today);
      if (sections.isEmpty || sections.last.label != label) {
        sections.add(StickySection(label: label, children: <Widget>[]));
      }
      sections.last.children.add(_ActivityRow(activity: a));
    }
    return BackToTop(
      builder: (ScrollController controller) => StickySectionList(
        controller: controller,
        sections: sections,
        padding: const EdgeInsets.only(bottom: 16),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final FeedActivity activity;

  (IconData, Color) get _visual => switch (activity.action) {
    'created' => (Icons.add_circle_rounded, AppColors.brand),
    'completed' => (Icons.check_circle_rounded, AppColors.green),
    'reopened' => (Icons.replay_rounded, AppColors.orange),
    'status' => (Icons.swap_horiz_rounded, AppColors.sky),
    'comment' => (Icons.chat_bubble_rounded, AppColors.violet),
    'updated' => (Icons.edit_rounded, AppColors.slate),
    _ => (Icons.circle, AppColors.slate),
  };

  String get _verb => switch (activity.action) {
    'created' => 'created',
    'completed' => 'completed',
    'reopened' => 'reopened',
    'status' => 'updated the status of',
    'comment' => 'commented on',
    'updated' => 'edited',
    _ => activity.action,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = _visual;
    final String task = activity.taskTitle.isEmpty
        ? 'a task'
        : activity.taskTitle;
    return InkWell(
      onTap: () => context.go('/tasks'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: scheme.onSurface,
                  ),
                  children: <InlineSpan>[
                    TextSpan(
                      text: activity.actorName.isEmpty
                          ? 'Someone'
                          : activity.actorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' $_verb '),
                    TextSpan(
                      text: task,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              relativeTime(activity.createdAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
