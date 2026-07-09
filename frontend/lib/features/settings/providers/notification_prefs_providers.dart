import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_prefs.dart';
import '../../../data/repositories/notification_prefs_repository.dart';
import '../../../providers/dio_provider.dart';

/// The notification-preferences repository, from the shared Dio client.
final Provider<NotificationPrefsRepository>
notificationPrefsRepositoryProvider = Provider<NotificationPrefsRepository>((
  ref,
) {
  return NotificationPrefsRepository(ref.watch(dioProvider));
});

/// The current user's notification preferences. Invalidate to refresh.
final FutureProvider<NotificationPrefs> notificationPrefsProvider =
    FutureProvider<NotificationPrefs>((ref) {
      return ref.watch(notificationPrefsRepositoryProvider).get();
    });
