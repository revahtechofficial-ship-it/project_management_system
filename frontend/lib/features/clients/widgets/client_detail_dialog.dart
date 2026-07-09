import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/models/client.dart';
import '../../../data/repositories/clients_repository.dart';
import '../providers/clients_providers.dart';

/// Opens the client detail dialog: edit details, share the portal link, and
/// pick which projects the client can see.
Future<void> showClientDetailDialog(BuildContext context, int clientId) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) => _ClientDetailDialog(clientId: clientId),
  );
}

/// The public portal URL for a token (hash route on the current web origin).
String portalUrl(String token) => '${Uri.base.origin}/#/portal/$token';

class _ClientDetailDialog extends ConsumerStatefulWidget {
  const _ClientDetailDialog({required this.clientId});
  final int clientId;

  @override
  ConsumerState<_ClientDetailDialog> createState() =>
      _ClientDetailDialogState();
}

class _ClientDetailDialogState extends ConsumerState<_ClientDetailDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final Set<int> _selected = <int>{};
  bool _seeded = false;
  bool _projectsSeeded = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    super.dispose();
  }

  Client? _clientOf(WidgetRef ref) {
    final List<Client> clients =
        ref.watch(clientsProvider).asData?.value ?? const <Client>[];
    for (final Client c in clients) {
      if (c.id == widget.clientId) {
        return c;
      }
    }
    return null;
  }

  Future<void> _saveDetails() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(clientsRepositoryProvider)
          .update(
            widget.clientId,
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
          );
      ref.invalidate(clientsProvider);
      if (mounted) {
        context.showSuccess('Client saved');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveProjects() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(clientsRepositoryProvider)
          .setProjects(widget.clientId, _selected.toList());
      ref.invalidate(clientProjectsProvider(widget.clientId));
      ref.invalidate(clientsProvider);
      if (mounted) {
        context.showSuccess('Projects updated');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not update projects: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete client?'),
            content: const Text(
              'Their projects are unassigned but not deleted.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(clientsRepositoryProvider).delete(widget.clientId);
      ref.invalidate(clientsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        context.showSuccess('Client deleted');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Client? client = _clientOf(ref);
    if (client != null && !_seeded) {
      _name.text = client.name;
      _company.text = client.company;
      _email.text = client.email;
      _seeded = true;
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: client == null
            ? const SizedBox(height: 240, child: LoadingView())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: <Widget>[
                        Text(
                          client.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextField(
                            controller: _company,
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
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _saveDetails,
                              child: const Text('Save details'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _PortalLink(token: client.portalToken),
                          const SizedBox(height: 16),
                          Text(
                            'Projects the client can see',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _ProjectPicker(
                            clientId: widget.clientId,
                            selected: _selected,
                            onSeed: (Set<int> ids) {
                              if (!_projectsSeeded) {
                                _selected
                                  ..clear()
                                  ..addAll(ids);
                                _projectsSeeded = true;
                              }
                            },
                            onToggle: (int id, bool on) => setState(() {
                              if (on) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Delete client',
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: _delete,
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy ? null : _saveProjects,
                          child: const Text('Save projects'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PortalLink extends StatelessWidget {
  const _PortalLink({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String url = portalUrl(token);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            tooltip: 'Open portal',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.open_in_new, size: 16),
            onPressed: () =>
                launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
          ),
          IconButton(
            tooltip: 'Copy portal link',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                context.showSuccess('Portal link copied');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectPicker extends ConsumerWidget {
  const _ProjectPicker({
    required this.clientId,
    required this.selected,
    required this.onSeed,
    required this.onToggle,
  });
  final int clientId;
  final Set<int> selected;
  final ValueChanged<Set<int>> onSeed;
  final void Function(int id, bool on) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ClientProjectFlag>> async = ref.watch(
      clientProjectsProvider(clientId),
    );
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => ErrorNotice(error: e),
      data: (List<ClientProjectFlag> flags) {
        onSeed(<int>{
          for (final ClientProjectFlag f in flags)
            if (f.assigned) f.id,
        });
        if (flags.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No projects to assign yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final ClientProjectFlag f in flags)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: selected.contains(f.id),
                title: Text(f.name, overflow: TextOverflow.ellipsis),
                onChanged: (bool? v) => onToggle(f.id, v ?? false),
              ),
          ],
        );
      },
    );
  }
}
