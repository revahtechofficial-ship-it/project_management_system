import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_activity.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../providers/dio_provider.dart';

/// The workspace activity repository, built from the shared Dio client
/// (AGENTS.md §1 `features/[feature]/providers`).
final Provider<ActivityRepository> activityRepositoryProvider =
    Provider<ActivityRepository>((ref) {
      return ActivityRepository(ref.watch(dioProvider));
    });

/// The workspace-wide collaboration history. Invalidate to refresh.
final FutureProvider<List<FeedActivity>> activityFeedProvider =
    FutureProvider<List<FeedActivity>>((ref) {
      return ref.watch(activityRepositoryProvider).recent();
    });
