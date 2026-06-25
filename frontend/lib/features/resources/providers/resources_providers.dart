import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/availability_entry.dart';
import '../../../data/models/member_capacity.dart';
import '../../../data/repositories/resources_repository.dart';
import '../../../providers/dio_provider.dart';

/// The resources repository, built from the shared Dio client. Feature-scoped
/// (AGENTS.md §1 `features/[feature]/providers`).
final Provider<ResourcesRepository> resourcesRepositoryProvider =
    Provider<ResourcesRepository>((ref) {
      return ResourcesRepository(ref.watch(dioProvider));
    });

/// Each member's weekly capacity (hours). Invalidate to refresh.
final FutureProvider<List<MemberCapacity>> capacityProvider =
    FutureProvider<List<MemberCapacity>>((ref) {
      return ref.watch(resourcesRepositoryProvider).capacity();
    });

/// All recorded time off across the team. Invalidate to refresh.
final FutureProvider<List<AvailabilityEntry>> availabilityProvider =
    FutureProvider<List<AvailabilityEntry>>((ref) {
      return ref.watch(resourcesRepositoryProvider).availability();
    });
