import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/attachment.dart';
import '../../../data/repositories/attachments_repository.dart';
import '../../../providers/dio_provider.dart';

/// The attachments repository, built from the shared Dio client (AGENTS.md §1).
final Provider<AttachmentsRepository> attachmentsRepositoryProvider =
    Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.watch(dioProvider));
});

/// Attachments for a task. Invalidate to refresh.
final attachmentsProvider =
    FutureProvider.family<List<Attachment>, int>((ref, int taskId) {
  return ref.watch(attachmentsRepositoryProvider).list(taskId);
});
