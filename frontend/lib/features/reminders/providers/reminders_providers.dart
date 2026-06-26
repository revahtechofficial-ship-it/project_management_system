import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/reminder.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../providers/dio_provider.dart';

/// The reminders repository (AGENTS.md §1).
final Provider<RemindersRepository> remindersRepositoryProvider =
    Provider<RemindersRepository>((ref) {
      return RemindersRepository(ref.watch(dioProvider));
    });

/// The current user's reminders, soonest first. Invalidate to refresh.
final FutureProvider<List<Reminder>> remindersProvider =
    FutureProvider<List<Reminder>>((ref) {
      return ref.watch(remindersRepositoryProvider).list();
    });
