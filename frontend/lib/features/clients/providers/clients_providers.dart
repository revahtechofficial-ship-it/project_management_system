import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/client.dart';
import '../../../data/models/portal_data.dart';
import '../../../data/repositories/clients_repository.dart';
import '../../../providers/dio_provider.dart';

/// The clients repository, from the shared Dio client (AGENTS.md §1).
final Provider<ClientsRepository> clientsRepositoryProvider =
    Provider<ClientsRepository>((ref) {
      return ClientsRepository(ref.watch(dioProvider));
    });

/// All clients. Invalidate to refresh after a change.
final FutureProvider<List<Client>> clientsProvider =
    FutureProvider<List<Client>>((ref) {
      return ref.watch(clientsRepositoryProvider).list();
    });

/// Project-assignment flags for a client, keyed by client id.
final clientProjectsProvider =
    FutureProvider.family<List<ClientProjectFlag>, int>((ref, int clientId) {
      return ref.watch(clientsRepositoryProvider).projects(clientId);
    });

/// A client portal's data, keyed by portal token (public, no auth).
final portalDataProvider = FutureProvider.family<PortalData, String>((
  ref,
  String token,
) {
  return ref.watch(clientsRepositoryProvider).portal(token);
});
