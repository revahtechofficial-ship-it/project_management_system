import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/leave_request.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../providers/dio_provider.dart';

/// The leave repository, from the shared Dio client (AGENTS.md §1).
final Provider<LeaveRepository> leaveRepositoryProvider =
    Provider<LeaveRepository>((ref) {
      return LeaveRepository(ref.watch(dioProvider));
    });

/// The current user's leave requests. Invalidate to refresh.
final FutureProvider<List<LeaveRequest>> myLeaveProvider =
    FutureProvider<List<LeaveRequest>>((ref) {
      return ref.watch(leaveRepositoryProvider).listMine();
    });

/// The current user's vacation balance.
final FutureProvider<LeaveBalance> leaveBalanceProvider =
    FutureProvider<LeaveBalance>((ref) {
      return ref.watch(leaveRepositoryProvider).balance();
    });

/// Approved leave in the coming weeks (who's out). Invalidate to refresh.
final FutureProvider<List<LeaveRequest>> leaveCalendarProvider =
    FutureProvider<List<LeaveRequest>>((ref) {
      return ref.watch(leaveRepositoryProvider).calendar();
    });

/// Pending requests awaiting approval (admin). Invalidate to refresh.
final FutureProvider<List<LeaveRequest>> pendingLeaveProvider =
    FutureProvider<List<LeaveRequest>>((ref) {
      return ref.watch(leaveRepositoryProvider).pending();
    });
