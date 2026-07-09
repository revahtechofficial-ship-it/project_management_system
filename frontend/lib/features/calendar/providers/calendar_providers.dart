import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../providers/dio_provider.dart';

/// The calendar-feed repository, from the shared Dio client (AGENTS.md §1).
final Provider<CalendarRepository> calendarRepositoryProvider =
    Provider<CalendarRepository>((ref) {
      return CalendarRepository(ref.watch(dioProvider));
    });

/// The current user's calendar feed token ('' when no feed is enabled).
/// Invalidate to refresh after enabling / rotating / revoking.
final FutureProvider<String> calendarTokenProvider = FutureProvider<String>((
  ref,
) {
  return ref.watch(calendarRepositoryProvider).token();
});
