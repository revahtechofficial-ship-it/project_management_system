import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../data/models/task.dart';
import '../../../data/models/time_entry.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../providers/time_providers.dart';

/// Opens the manual log / edit dialog. Returns true if an entry was saved.
Future<bool?> showTimeEntryDialog(BuildContext context, {TimeEntry? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _TimeEntryDialog(existing: existing),
  );
}

class _TimeEntryDialog extends ConsumerStatefulWidget {
  const _TimeEntryDialog({this.existing});

  final TimeEntry? existing;

  @override
  ConsumerState<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends ConsumerState<_TimeEntryDialog> {
  late final TextEditingController _hours;
  late final TextEditingController _mins;
  late final TextEditingController _desc;
  late DateTime _date;
  int? _taskId;
  bool _billable = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final TimeEntry? e = widget.existing;
    _hours = TextEditingController(text: e == null ? '' : '${e.minutes ~/ 60}');
    _mins = TextEditingController(text: e == null ? '' : '${e.minutes % 60}');
    _desc = TextEditingController(text: e?.description ?? '');
    _date = e?.startedAt.toLocal() ?? DateTime.now();
    _taskId = e?.taskId;
    _billable = e?.billable ?? false;
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final int minutes =
        (int.tryParse(_hours.text.trim()) ?? 0) * 60 +
        (int.tryParse(_mins.text.trim()) ?? 0);
    if (minutes <= 0) {
      context.showSuccess('Enter a duration above zero');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(timeEntriesRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          taskId: _taskId,
          minutes: minutes,
          date: _ymd(_date),
          description: _desc.text.trim(),
          billable: _billable,
        );
      } else {
        await repo.create(
          taskId: _taskId,
          minutes: minutes,
          date: _ymd(_date),
          description: _desc.text.trim(),
          billable: _billable,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showError('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    return AlertDialog(
      title: Text(_isEdit ? 'Edit time entry' : 'Log time'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mins,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  isDense: true,
                  suffixIcon: Icon(Icons.event, size: 20),
                ),
                child: Text(shortDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: tasks.any((Task t) => t.id == _taskId)
                  ? _taskId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Task',
                isDense: true,
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No task'),
                ),
                for (final Task t in tasks)
                  DropdownMenuItem<int?>(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (int? v) => setState(() => _taskId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Description',
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Billable'),
              value: _billable,
              onChanged: (bool v) => setState(() => _billable = v),
            ),
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
          child: Text(_isEdit ? 'Save' : 'Log'),
        ),
      ],
    );
  }
}
