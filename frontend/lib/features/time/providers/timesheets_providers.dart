import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/timesheet_submission.dart';
import '../../../data/repositories/timesheets_repository.dart';
import '../../../providers/dio_provider.dart';

/// The timesheets repository, from the shared Dio client (AGENTS.md §1).
final Provider<TimesheetsRepository> timesheetsRepositoryProvider =
    Provider<TimesheetsRepository>((ref) {
      return TimesheetsRepository(ref.watch(dioProvider));
    });

/// The current user's recent timesheet submissions. Invalidate to refresh.
final FutureProvider<List<TimesheetSubmission>> myTimesheetsProvider =
    FutureProvider<List<TimesheetSubmission>>((ref) {
      return ref.watch(timesheetsRepositoryProvider).listMine();
    });

/// Pending submissions awaiting approval (admin-only). Invalidate to refresh.
final FutureProvider<List<TimesheetSubmission>> pendingTimesheetsProvider =
    FutureProvider<List<TimesheetSubmission>>((ref) {
      return ref.watch(timesheetsRepositoryProvider).pending();
    });
