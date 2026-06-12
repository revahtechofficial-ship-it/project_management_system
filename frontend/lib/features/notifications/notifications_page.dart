import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/app_notification.dart';
import 'providers/notifications_providers.dart';

/// The workspace notification feed, backed by `/api/v1/notifications`.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AppNotification>> async =
        ref.watch(notificationsProvider);
    final List<AppNotification> items =
        async.asData?.value ?? const <AppNotification>[];
    final int unread = items.where((AppNotification n) => !n.read).length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            PageHeader(
              title: 'Notifications',
              subtitle: unread == 0
                  ? 'You are all caught up'
                  : '$unread unread notification${unread == 1 ? '' : 's'}',
              actions: <Widget>[
                TextButton.icon(
                  onPressed: unread == 0
                      ? null
                      : () => _markAll(ref),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all as read'),
                ),
              ],
            ),
            if (async.isLoading) const LoadingBar(),
            if (async.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ErrorNotice(error: async.error!),
              ),
            const SizedBox(height: 20),
            if (items.isEmpty && !async.isLoading)
              const EmptyState(
                icon: Icons.notifications_off_rounded,
                message: 'No notifications yet.',
              )
            else
              DashboardCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++) ...<Widget>[
                      _NotifTile(notif: items[i]),
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

  Future<void> _markAll(WidgetRef ref) async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }
}

class _NotifTile extends ConsumerWidget {
  const _NotifTile({required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = _visual(notif.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(notif.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: notif.body.isEmpty ? null : Text(notif.body),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(relativeTime(notif.createdAt),
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          if (!notif.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.brand, shape: BoxShape.circle),
            ),
        ],
      ),
      onTap: notif.read
          ? null
          : () async {
              await ref
                  .read(notificationsRepositoryProvider)
                  .markRead(notif.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
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
