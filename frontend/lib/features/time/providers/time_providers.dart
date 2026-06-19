import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/time_entry.dart';
import '../../../data/repositories/time_entries_repository.dart';
import '../../../providers/dio_provider.dart';

/// The time-entries repository, from the shared Dio client (AGENTS.md §1).
final Provider<TimeEntriesRepository> timeEntriesRepositoryProvider =
    Provider<TimeEntriesRepository>((ref) {
      return TimeEntriesRepository(ref.watch(dioProvider));
    });

/// The current user's recent time entries. Invalidate to refresh.
final FutureProvider<List<TimeEntry>> myTimeEntriesProvider =
    FutureProvider<List<TimeEntry>>((ref) {
      return ref.watch(timeEntriesRepositoryProvider).list();
    });

/// The currently running timer, or null. Invalidate to refresh.
final FutureProvider<TimeEntry?> activeTimerProvider =
    FutureProvider<TimeEntry?>((ref) {
      return ref.watch(timeEntriesRepositoryProvider).active();
    });
