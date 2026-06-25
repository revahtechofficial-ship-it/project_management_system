import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/api_key.dart';
import '../../../data/models/integration.dart';
import '../../../data/models/webhook.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../../../providers/dio_provider.dart';

/// The integrations repository, built from the shared Dio client
/// (AGENTS.md §1 `features/[feature]/providers`).
final Provider<IntegrationsRepository> integrationsRepositoryProvider =
    Provider<IntegrationsRepository>((ref) {
      return IntegrationsRepository(ref.watch(dioProvider));
    });

/// Connected integrations, keyed by provider. Invalidate to refresh.
final FutureProvider<Map<String, Integration>> integrationsProvider =
    FutureProvider<Map<String, Integration>>((ref) async {
      final List<Integration> list = await ref
          .watch(integrationsRepositoryProvider)
          .integrations();
      return <String, Integration>{
        for (final Integration i in list) i.provider: i,
      };
    });

/// The current user's personal API keys. Invalidate to refresh.
final FutureProvider<List<ApiKey>> apiKeysProvider =
    FutureProvider<List<ApiKey>>((ref) {
      return ref.watch(integrationsRepositoryProvider).apiKeys();
    });

/// Outgoing webhooks. Invalidate to refresh.
final FutureProvider<List<Webhook>> webhooksProvider =
    FutureProvider<List<Webhook>>((ref) {
      return ref.watch(integrationsRepositoryProvider).webhooks();
    });
