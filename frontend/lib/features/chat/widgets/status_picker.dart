import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/user_status.dart';
import '../../../data/models/user_presence.dart';
import '../../../providers/auth_provider.dart';
import '../providers/chat_providers.dart';

/// Opens the "set your status" dialog.
Future<void> showStatusPicker(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const _StatusPicker(),
  );
}

class _StatusPicker extends ConsumerStatefulWidget {
  const _StatusPicker();

  @override
  ConsumerState<_StatusPicker> createState() => _StatusPickerState();
}

class _StatusPickerState extends ConsumerState<_StatusPicker> {
  late UserStatus _status;
  late final TextEditingController _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final int? myId = ref.read(authControllerProvider).asData?.value.user?.id;
    final Map<int, UserPresence>? map = ref
        .read(presenceProvider)
        .asData
        ?.value;
    final UserPresence? mine = (map != null && myId != null) ? map[myId] : null;
    _status = mine?.status ?? UserStatus.active;
    _message = TextEditingController(text: mine?.statusMessage ?? '');
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setStatus(_status, _message.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set your status'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioGroup<UserStatus>(
              groupValue: _status,
              onChanged: (UserStatus? v) =>
                  setState(() => _status = v ?? UserStatus.active),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final UserStatus s in UserStatus.selectableValue)
                    RadioListTile<UserStatus>(
                      contentPadding: EdgeInsets.zero,
                      value: s,
                      title: Row(
                        children: <Widget>[
                          Icon(s.icon, size: 18, color: s.color),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Custom status message',
                hintText: 'e.g. In a meeting, On vacation…',
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
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
