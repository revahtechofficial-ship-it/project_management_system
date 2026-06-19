import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/comment.dart';
import '../../../data/repositories/comments_repository.dart';
import '../../../providers/dio_provider.dart';

/// The comments/activity repository, built from the shared Dio client.
final Provider<CommentsRepository> commentsRepositoryProvider =
    Provider<CommentsRepository>((ref) {
      return CommentsRepository(ref.watch(dioProvider));
    });

/// Comments for a task. Invalidate to refresh.
final commentsProvider = FutureProvider.family<List<Comment>, int>((
  ref,
  int taskId,
) {
  return ref.watch(commentsRepositoryProvider).list(taskId);
});

/// Activity timeline for a task. Invalidate to refresh.
final activityProvider = FutureProvider.family<List<Activity>, int>((
  ref,
  int taskId,
) {
  return ref.watch(commentsRepositoryProvider).listActivity(taskId);
});
