import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_notification.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../../providers/dio_provider.dart';

/// The notifications repository, built from the shared Dio client.
final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
      return NotificationsRepository(ref.watch(dioProvider));
    });

/// Recent notifications, newest first. Invalidate to refresh.
final FutureProvider<List<AppNotification>> notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) {
      return ref.watch(notificationsRepositoryProvider).list();
    });

/// Unread notification count, for the top-bar bell badge.
final FutureProvider<int> unreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
