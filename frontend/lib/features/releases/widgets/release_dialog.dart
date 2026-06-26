import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/enums/release_status.dart';
import '../../../data/models/release.dart';
import '../providers/releases_providers.dart';

/// Opens the create/edit release dialog.
Future<void> showReleaseDialog(BuildContext context, {Release? existing}) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _ReleaseDialog(existing: existing),
    );

class _ReleaseDialog extends ConsumerStatefulWidget {
  const _ReleaseDialog({this.existing});

  final Release? existing;

  @override
  ConsumerState<_ReleaseDialog> createState() => _ReleaseDialogState();
}

class _ReleaseDialogState extends ConsumerState<_ReleaseDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _version = TextEditingController(
    text: widget.existing?.version ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  late ReleaseStatus _status = widget.existing?.status ?? ReleaseStatus.planned;
  late DateTime? _target = widget.existing?.targetDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _target ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(() => _target = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final Release release = Release(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      version: _version.text.trim(),
      status: _status,
      targetDate: _target,
      notes: _notes.text.trim(),
    );
    try {
      final repo = ref.read(releasesRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!.id, release);
      } else {
        await repo.create(release);
      }
      ref.invalidate(releasesProvider);
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
      title: Text(_isEdit ? 'Edit release' : 'New release'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Summer launch',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _version,
                    decoration: const InputDecoration(
                      labelText: 'Version',
                      hintText: 'e.g. v2.1',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ReleaseStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: <DropdownMenuItem<ReleaseStatus>>[
                      for (final ReleaseStatus s in ReleaseStatus.values)
                        DropdownMenuItem<ReleaseStatus>(
                          value: s,
                          child: Text(s.label),
                        ),
                    ],
                    onChanged: (ReleaseStatus? s) =>
                        setState(() => _status = s ?? ReleaseStatus.planned),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _target == null
                    ? 'Set target date'
                    : 'Target ${shortDate(_target!)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
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
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
