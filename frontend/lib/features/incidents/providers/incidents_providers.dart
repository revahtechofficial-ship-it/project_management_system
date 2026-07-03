import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/incident.dart';
import '../../../data/repositories/incidents_repository.dart';
import '../../../providers/dio_provider.dart';

/// The incidents repository, from the shared Dio client (AGENTS.md §1).
final Provider<IncidentsRepository> incidentsRepositoryProvider =
    Provider<IncidentsRepository>((ref) {
  return IncidentsRepository(ref.watch(dioProvider));
});

/// Every bug and incident. Invalidate to refresh after a change.
final FutureProvider<List<Incident>> incidentsProvider =
    FutureProvider<List<Incident>>((ref) {
  return ref.watch(incidentsRepositoryProvider).list();
});
