import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/api_key.dart';
import '../../data/models/integration.dart';
import '../../data/models/webhook.dart';
import 'integration_catalog.dart';
import 'providers/integrations_providers.dart';
import 'widgets/integration_dialogs.dart';

/// The Integrations hub: a connectable app catalogue, personal API keys, and
/// outgoing webhooks (AGENTS.md §1 feature page).
class IntegrationsPage extends ConsumerStatefulWidget {
  const IntegrationsPage({super.key});

  @override
  ConsumerState<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends ConsumerState<IntegrationsPage> {
  _Tab _tab = _Tab.apps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Integrations',
            subtitle: 'Connect apps, manage API access and webhooks',
            actions: <Widget>[
              SegmentedButton<_Tab>(
                segments: const <ButtonSegment<_Tab>>[
                  ButtonSegment<_Tab>(
                    value: _Tab.apps,
                    icon: Icon(Icons.apps, size: 18),
                    label: Text('Apps'),
                  ),
                  ButtonSegment<_Tab>(
                    value: _Tab.apiKeys,
                    icon: Icon(Icons.key_outlined, size: 18),
                    label: Text('API keys'),
                  ),
                  ButtonSegment<_Tab>(
                    value: _Tab.webhooks,
                    icon: Icon(Icons.webhook_outlined, size: 18),
                    label: Text('Webhooks'),
                  ),
                ],
                selected: <_Tab>{_tab},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_Tab> s) =>
                    setState(() => _tab = s.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: switch (_tab) {
              _Tab.apps => const _AppsView(),
              _Tab.apiKeys => const _ApiKeysView(),
              _Tab.webhooks => const _WebhooksView(),
            },
          ),
        ],
      ),
    );
  }
}

enum _Tab { apps, apiKeys, webhooks }

// --- Apps catalogue --------------------------------------------------------

class _AppsView extends ConsumerWidget {
  const _AppsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Integration> connected =
        ref.watch(integrationsProvider).asData?.value ??
        const <String, Integration>{};
    final List<String> categories = <String>[];
    for (final IntegrationInfo i in kIntegrations) {
      if (!categories.contains(i.category)) {
        categories.add(i.category);
      }
    }
    return ListView(
      children: <Widget>[
        for (final String category in categories) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 10),
            child: Text(
              category,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              for (final IntegrationInfo info in kIntegrations.where(
                (IntegrationInfo i) => i.category == category,
              ))
                _IntegrationCard(
                  info: info,
                  integration: connected[info.provider],
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _IntegrationCard extends ConsumerWidget {
  const _IntegrationCard({required this.info, this.integration});

  final IntegrationInfo info;
  final Integration? integration;

  Future<void> _disconnect(WidgetRef ref) async {
    await ref.read(integrationsRepositoryProvider).disconnect(info.provider);
    ref.invalidate(integrationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isConnected = integration?.connected ?? false;
    return SizedBox(
      width: 280,
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: info.color.withValues(alpha: 0.15),
                  child: Icon(info.icon, color: info.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (info.isLive)
                  Tooltip(
                    message: 'Delivers live event notifications',
                    child: Icon(Icons.bolt, size: 16, color: AppColors.green),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: Text(
                info.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 10),
            if (isConnected)
              Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        showConnectDialog(context, info, integration),
                    child: const Text('Configure'),
                  ),
                  IconButton(
                    tooltip: 'Disconnect',
                    icon: const Icon(Icons.link_off, size: 18),
                    onPressed: () => _disconnect(ref),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => showConnectDialog(context, info, integration),
                  child: const Text('Connect'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- API keys --------------------------------------------------------------

class _ApiKeysView extends ConsumerWidget {
  const _ApiKeysView();

  Future<void> _delete(WidgetRef ref, int id) async {
    await ref.read(integrationsRepositoryProvider).deleteKey(id);
    ref.invalidate(apiKeysProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<ApiKey>> async = ref.watch(apiKeysProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Personal access tokens for the REST API. Send as '
                '“Authorization: Bearer <token>” or “X-API-Key: <token>”.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => showCreateApiKeyDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New key'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, _) => Center(child: Text('Failed to load:\n$e')),
            data: (List<ApiKey> keys) {
              if (keys.isEmpty) {
                return const EmptyState(
                  icon: Icons.key_outlined,
                  message: 'No API keys yet. Create one for programmatic '
                      'access.',
                );
              }
              return ListView.separated(
                itemCount: keys.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int i) =>
                    _ApiKeyRow(apiKey: keys[i], onDelete: () => _delete(ref, keys[i].id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ApiKeyRow extends StatelessWidget {
  const _ApiKeyRow({required this.apiKey, required this.onDelete});

  final ApiKey apiKey;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.key, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  apiKey.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${apiKey.prefix}••••••••  ·  '
                  '${apiKey.lastUsedAt == null ? 'never used' : 'used ${relativeTime(apiKey.lastUsedAt!)}'}'
                  '  ·  created ${shortDate(apiKey.createdAt.toLocal())}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Revoke',
            icon: const Icon(Icons.delete_outline),
            color: AppColors.rose,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// --- Webhooks --------------------------------------------------------------

class _WebhooksView extends ConsumerWidget {
  const _WebhooksView();

  Future<void> _toggle(WidgetRef ref, Webhook w, bool active) async {
    await ref.read(integrationsRepositoryProvider).updateWebhook(
          w.id,
          url: w.url,
          events: w.events,
          active: active,
        );
    ref.invalidate(webhooksProvider);
  }

  Future<void> _delete(WidgetRef ref, int id) async {
    await ref.read(integrationsRepositoryProvider).deleteWebhook(id);
    ref.invalidate(webhooksProvider);
  }

  Future<void> _test(BuildContext context, WidgetRef ref, int id) async {
    await ref.read(integrationsRepositoryProvider).testWebhook(id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test delivery sent')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<Webhook>> async = ref.watch(webhooksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Send a signed JSON POST to your endpoints when tasks change.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => showWebhookDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add webhook'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, _) => Center(child: Text('Failed to load:\n$e')),
            data: (List<Webhook> hooks) {
              if (hooks.isEmpty) {
                return const EmptyState(
                  icon: Icons.webhook_outlined,
                  message: 'No webhooks yet. Add one to receive task events.',
                );
              }
              return ListView.separated(
                itemCount: hooks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int i) => _WebhookRow(
                  webhook: hooks[i],
                  onToggle: (bool v) => _toggle(ref, hooks[i], v),
                  onTest: () => _test(context, ref, hooks[i].id),
                  onEdit: () =>
                      showWebhookDialog(context, existing: hooks[i]),
                  onDelete: () => _delete(ref, hooks[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WebhookRow extends StatelessWidget {
  const _WebhookRow({
    required this.webhook,
    required this.onToggle,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  final Webhook webhook;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String events = webhook.allEvents
        ? 'All events'
        : webhook.events
              .map(
                (String e) => kWebhookEvents
                    .firstWhere(
                      ((String, String) k) => k.$1 == e,
                      orElse: () => (e, e),
                    )
                    .$2,
              )
              .join(', ');
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.webhook,
            color: webhook.active ? AppColors.brand : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  webhook.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$events${webhook.hasSecret ? '  ·  signed' : ''}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: webhook.active, onChanged: onToggle),
          IconButton(
            tooltip: 'Send test',
            icon: const Icon(Icons.send_outlined, size: 18),
            onPressed: onTest,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.rose,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
