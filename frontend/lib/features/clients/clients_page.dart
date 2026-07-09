import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/client.dart';
import 'providers/clients_providers.dart';
import 'widgets/client_detail_dialog.dart';

/// Clients: external clients and their read-only portals.
class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  Future<void> _create() async {
    final Client? created = await showCreateClientDialog(context);
    if (created != null && mounted) {
      await showClientDetailDialog(context, created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Client>> async = ref.watch(clientsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Clients',
            subtitle: 'External clients & portals',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New client'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(clientsProvider),
              ),
              data: (List<Client> clients) {
                if (clients.isEmpty) {
                  return EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'No clients yet',
                    message:
                        'Add a client, assign their projects, and share a '
                        'read-only portal link so they can track progress and '
                        'invoices.',
                    actionLabel: 'Add a client',
                    actionIcon: Icons.add,
                    onAction: _create,
                  );
                }
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: <Widget>[
                      for (final Client c in clients)
                        SizedBox(
                          width: 360,
                          child: _ClientCard(
                            client: c,
                            onTap: () => showClientDetailDialog(context, c.id),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});
  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Client c = client;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DashboardCard(
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Text(
                c.displayName.characters.first.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    c.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    <String>[
                      if (c.company.isNotEmpty && c.name.isNotEmpty) c.company,
                      if (c.email.isNotEmpty) c.email,
                      '${c.projectCount} '
                          '${c.projectCount == 1 ? 'project' : 'projects'}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A small dialog to create a client. Returns the created client.
Future<Client?> showCreateClientDialog(BuildContext context) {
  return showDialog<Client>(
    context: context,
    builder: (BuildContext _) => const _CreateClientDialog(),
  );
}

class _CreateClientDialog extends ConsumerStatefulWidget {
  const _CreateClientDialog();

  @override
  ConsumerState<_CreateClientDialog> createState() =>
      _CreateClientDialogState();
}

class _CreateClientDialogState extends ConsumerState<_CreateClientDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty && _company.text.trim().isEmpty) {
      context.showError('Enter a name or company');
      return;
    }
    setState(() => _busy = true);
    try {
      final Client c = await ref
          .read(clientsRepositoryProvider)
          .create(
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
          );
      ref.invalidate(clientsProvider);
      if (mounted) {
        Navigator.of(context).pop(c);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not create: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New client'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _company,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Company',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
