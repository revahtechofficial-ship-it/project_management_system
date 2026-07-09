import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../providers/reminders_providers.dart';

/// Opens the "set a reminder" dialog. Optionally attach it to a task via
/// [taskId] / [taskTitle]. Returns true when a reminder was created.
Future<bool?> showReminderDialog(
  BuildContext context, {
  int? taskId,
  String taskTitle = '',
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext context) =>
      _ReminderDialog(taskId: taskId, taskTitle: taskTitle),
);

class _ReminderDialog extends ConsumerStatefulWidget {
  const _ReminderDialog({this.taskId, this.taskTitle = ''});

  final int? taskId;
  final String taskTitle;

  @override
  ConsumerState<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<_ReminderDialog> {
  late final TextEditingController _note = TextEditingController(
    text: widget.taskTitle,
  );
  late DateTime _when = _defaultWhen();
  bool _saving = false;
  String? _error;

  static DateTime _defaultWhen() {
    final DateTime n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(
        () =>
            _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute),
      );
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t != null) {
      setState(
        () => _when = DateTime(
          _when.year,
          _when.month,
          _when.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (widget.taskId == null && _note.text.trim().isEmpty) {
      setState(() => _error = 'Add a note for the reminder');
      return;
    }
    if (_when.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(remindersRepositoryProvider)
          .create(
            remindAt: _when,
            note: _note.text.trim(),
            taskId: widget.taskId,
          );
      ref.invalidate(remindersProvider);
      if (mounted) {
        Navigator.pop(context, true);
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
      title: const Text('Set a reminder'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _note,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Remind me to…',
                hintText: 'e.g. follow up with the client',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(shortDate(_when)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(TimeOfDay.fromDateTime(_when).format(context)),
                  ),
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
          child: const Text('Set reminder'),
        ),
      ],
    );
  }
}
