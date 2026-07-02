import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/approval.dart';
import '../../../data/repositories/approvals_repository.dart';
import '../../../providers/dio_provider.dart';

/// The approvals repository, from the shared Dio client (AGENTS.md §1).
final Provider<ApprovalsRepository> approvalsRepositoryProvider =
    Provider<ApprovalsRepository>((ref) {
  return ApprovalsRepository(ref.watch(dioProvider));
});

/// Approvals awaiting the current user's decision. Invalidate to refresh.
final FutureProvider<List<Approval>> pendingApprovalsProvider =
    FutureProvider<List<Approval>>((ref) {
  return ref.watch(approvalsRepositoryProvider).pending();
});

/// The current user's own approval requests. Invalidate to refresh.
final FutureProvider<List<Approval>> myApprovalRequestsProvider =
    FutureProvider<List<Approval>>((ref) {
  return ref.watch(approvalsRepositoryProvider).mine();
});

/// Approvals on one subject, keyed by "type:id".
final approvalsForSubjectProvider =
    FutureProvider.family<List<Approval>, ({String type, int id})>(
        (ref, ({String type, int id}) key) {
  return ref.watch(approvalsRepositoryProvider).forSubject(key.type, key.id);
});
