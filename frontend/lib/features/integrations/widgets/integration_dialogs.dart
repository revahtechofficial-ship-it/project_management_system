import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/integration.dart';
import '../../../data/models/webhook.dart';
import '../../../data/repositories/integrations_repository.dart';
import '../integration_catalog.dart';
import '../providers/integrations_providers.dart';

/// Connect / configure a catalogue integration.
Future<void> showConnectDialog(
  BuildContext context,
  IntegrationInfo info,
  Integration? existing,
) => showDialog<void>(
  context: context,
  builder: (BuildContext context) =>
      _ConnectDialog(info: info, existing: existing),
);

class _ConnectDialog extends ConsumerStatefulWidget {
  const _ConnectDialog({required this.info, this.existing});

  final IntegrationInfo info;
  final Integration? existing;

  @override
  ConsumerState<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<_ConnectDialog> {
  late final TextEditingController _primary = TextEditingController(
    text: widget.existing?.config[widget.info.primaryKey] ?? '',
  );
  late final TextEditingController _link = TextEditingController(
    text: widget.existing?.config['url'] ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _primary.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_primary.text.trim().isEmpty) {
      setState(() => _error = '${widget.info.primaryLabel} is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final Map<String, String> config = <String, String>{
      widget.info.primaryKey: _primary.text.trim(),
      if (!widget.info.isLive && _link.text.trim().isNotEmpty)
        'url': _link.text.trim(),
    };
    try {
      await ref
          .read(integrationsRepositoryProvider)
          .connect(widget.info.provider, connected: true, config: config);
      ref.invalidate(integrationsProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final IntegrationInfo info = widget.info;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(info.icon, color: info.color),
          const SizedBox(width: 10),
          Text('Connect ${info.name}'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(info.description, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _primary,
              autofocus: true,
              obscureText: info.masked,
              decoration: InputDecoration(
                labelText: info.primaryLabel,
                hintText: info.isLive ? 'https://…' : null,
              ),
            ),
            if (!info.isLive) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _link,
                decoration: const InputDecoration(
                  labelText: 'Link (optional)',
                  hintText: 'Repo / folder / workspace URL',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    info.isLive ? Icons.bolt : Icons.info_outline,
                    size: 16,
                    color: info.isLive ? AppColors.green : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info.isLive
                          ? 'Task events will be delivered to this URL in '
                                'real time.'
                          : 'Saved to your workspace. Used to link and embed '
                                '${info.name} resources.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.existing?.connected == true ? 'Save' : 'Connect'),
        ),
      ],
    );
  }
}

/// Create an API key, then reveal the plaintext token exactly once.
Future<void> showCreateApiKeyDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => const _ApiKeyDialog(),
    );

class _ApiKeyDialog extends ConsumerStatefulWidget {
  const _ApiKeyDialog();

  @override
  ConsumerState<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<_ApiKeyDialog> {
  final TextEditingController _name = TextEditingController();
  bool _saving = false;
  String? _token;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final CreatedApiKey created = await ref
          .read(integrationsRepositoryProvider)
          .createKey(_name.text.trim().isEmpty ? 'API key' : _name.text.trim());
      ref.invalidate(apiKeysProvider);
      setState(() {
        _saving = false;
        _token = created.token;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create key: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_token != null) {
      return AlertDialog(
        title: const Text('Copy your API key'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'This is the only time the full key is shown. Store it safely.',
                style: TextStyle(color: AppColors.rose),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SelectableText(
                        _token!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _token!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Send it as an Authorization: Bearer header, or X-API-Key.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: const Text('New API key'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. CI pipeline',
          ),
          onSubmitted: (_) => _create(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Create or edit an outgoing webhook.
Future<void> showWebhookDialog(BuildContext context, {Webhook? existing}) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _WebhookDialog(existing: existing),
    );

class _WebhookDialog extends ConsumerStatefulWidget {
  const _WebhookDialog({this.existing});

  final Webhook? existing;

  @override
  ConsumerState<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends ConsumerState<_WebhookDialog> {
  late final TextEditingController _url = TextEditingController(
    text: widget.existing?.url ?? '',
  );
  final TextEditingController _secret = TextEditingController();
  late final Set<String> _events = <String>{...?widget.existing?.events};
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_url.text.trim().isEmpty) {
      setState(() => _error = 'A URL is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final IntegrationsRepository repo = ref.read(
        integrationsRepositoryProvider,
      );
      if (_isEdit) {
        await repo.updateWebhook(
          widget.existing!.id,
          url: _url.text.trim(),
          events: _events.toList(),
          active: widget.existing!.active,
        );
      } else {
        await repo.createWebhook(
          url: _url.text.trim(),
          secret: _secret.text.trim(),
          events: _events.toList(),
        );
      }
      ref.invalidate(webhooksProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit webhook' : 'New webhook'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _url,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Payload URL',
                hintText: 'https://example.com/hook',
              ),
            ),
            if (!_isEdit) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _secret,
                decoration: const InputDecoration(
                  labelText: 'Signing secret (optional)',
                  hintText: 'Used for the X-Revah-Signature header',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Events  (none = all)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (String key, String label) in kWebhookEvents)
                  FilterChip(
                    label: Text(label),
                    selected: _events.contains(key),
                    onSelected: (bool v) => setState(() {
                      if (v) {
                        _events.add(key);
                      } else {
                        _events.remove(key);
                      }
                    }),
                  ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
