import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/app_notification.dart';
import 'providers/notifications_providers.dart';

/// The filters offered in the Inbox.
enum _Filter {
  all,
  unread,
  mentions,
  assigned;

  String get label => switch (this) {
    _Filter.all => 'All',
    _Filter.unread => 'Unread',
    _Filter.mentions => 'Mentions',
    _Filter.assigned => 'Assigned',
  };

  bool matches(AppNotification n) => switch (this) {
    _Filter.all => true,
    _Filter.unread => !n.read,
    _Filter.mentions => n.type == 'mention',
    _Filter.assigned => n.type == 'assigned' || n.type == 'comment',
  };
}

/// The Inbox: a unified, filterable feed of everything needing attention —
/// mentions, assignments and comments — backed by `/api/v1/notifications`.
/// Each item deep-links to the relevant section (AGENTS.md §1 feature page).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _Filter _filter = _Filter.all;

  Future<void> _markAll() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      await ref.read(notificationsRepositoryProvider).markRead(n.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    }
    if (n.link.isNotEmpty && mounted) {
      context.go(n.link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> async = ref.watch(
      notificationsProvider,
    );
    final List<AppNotification> all =
        async.asData?.value ?? const <AppNotification>[];
    final int unread = all.where((AppNotification n) => !n.read).length;
    final List<AppNotification> items = all
        .where(_filter.matches)
        .toList(growable: false);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            PageHeader(
              title: 'Inbox',
              subtitle: unread == 0
                  ? 'You are all caught up'
                  : '$unread unread item${unread == 1 ? '' : 's'}',
              actions: <Widget>[
                TextButton.icon(
                  onPressed: unread == 0 ? null : _markAll,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all as read'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<_Filter>(
              segments: <ButtonSegment<_Filter>>[
                for (final _Filter f in _Filter.values)
                  ButtonSegment<_Filter>(value: f, label: Text(f.label)),
              ],
              selected: <_Filter>{_filter},
              showSelectedIcon: false,
              onSelectionChanged: (Set<_Filter> s) =>
                  setState(() => _filter = s.first),
            ),
            if (async.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LoadingBar(),
              ),
            if (async.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ErrorNotice(error: async.error!),
              ),
            const SizedBox(height: 16),
            if (items.isEmpty && !async.isLoading)
              EmptyState(
                icon: Icons.inbox_rounded,
                message: _filter == _Filter.all
                    ? 'Your inbox is empty.'
                    : 'Nothing in "${_filter.label}".',
              )
            else
              DashboardCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++) ...<Widget>[
                      _NotifTile(notif: items[i], onTap: () => _open(items[i])),
                      if (i != items.length - 1)
                        const Divider(height: 1, indent: 56),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.onTap});

  final AppNotification notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = _visual(notif.type);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        notif.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: notif.body.isEmpty
          ? null
          : Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            relativeTime(notif.createdAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          if (!notif.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _visual(String type) => switch (type) {
    'assigned' => (Icons.assignment_ind_rounded, AppColors.brand),
    'mention' => (Icons.alternate_email_rounded, AppColors.violet),
    'comment' => (Icons.mode_comment_rounded, AppColors.sky),
    'reminder' => (Icons.alarm_rounded, AppColors.amber),
    'task' => (Icons.check_circle_rounded, AppColors.green),
    'project' => (Icons.folder_rounded, AppColors.brand),
    'member' => (Icons.person_add_alt_1, AppColors.violet),
    _ => (Icons.notifications_rounded, AppColors.sky),
  };
}
