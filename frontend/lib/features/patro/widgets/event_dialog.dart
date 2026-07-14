import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/calendar_entry_kind.dart';
import '../../../data/models/calendar_entry.dart';
import '../../../data/repositories/calendar_entries_repository.dart';
import '../providers/patro_providers.dart';

/// Opens the personal-event editor. Pass [existing] to edit, or [initialDate]
/// to add. Returns true when saved.
Future<bool?> showEventDialog(
  BuildContext context, {
  DateTime? initialDate,
  CalendarEntry? existing,
  bool remindByDefault = false,
}) {
  assert(
    initialDate != null || existing != null,
    'needs either a date to add on, or an entry to edit',
  );
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _EventDialog(
      initialDate: initialDate,
      existing: existing,
      remindByDefault: remindByDefault,
    ),
  );
}

class _EventDialog extends ConsumerStatefulWidget {
  const _EventDialog({
    this.initialDate,
    this.existing,
    this.remindByDefault = false,
  });

  final DateTime? initialDate;
  final CalendarEntry? existing;

  /// Opened from the hover card's "Remind" button, which is the same form with
  /// the reminder already asked for.
  final bool remindByDefault;

  @override
  ConsumerState<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<_EventDialog> {
  late final CalendarEntry? _existing = widget.existing;

  late final TextEditingController _title = TextEditingController(
    text: _existing?.title ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: _existing?.note ?? '',
  );

  late DateTime _date = dateOnly(
    _existing?.date ?? widget.initialDate ?? DateTime.now(),
  );
  late CalendarEntryKind _kind = _existing?.kind ?? CalendarEntryKind.note;
  late RepeatIn _repeat = _existing?.repeatIn ?? RepeatIn.none;
  late TimeOfDay? _start = _parse(_existing?.startTime);
  late TimeOfDay? _end = _parse(_existing?.endTime);
  late int? _remindDays =
      _existing?.remindDays ?? (widget.remindByDefault ? 0 : null);
  bool _busy = false;

  static TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) {
      return null;
    }
    final List<String> parts = hhmm.split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static String _format(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Picking a birthday or an anniversary sets the sensible default — repeat
  /// yearly by the Nepali date, which is how they are usually kept here — but
  /// never overrides a choice already made.
  void _setKind(CalendarEntryKind kind) {
    setState(() {
      _kind = kind;
      if (kind.repeatsByDefault && _repeat == RepeatIn.none) {
        _repeat = RepeatIn.bs;
        _remindDays ??= 1;
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A birthday can be decades back.
      firstDate: DateTime(1944),
      lastDate: DateTime(2043, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ?? TimeOfDay.now(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  CalendarEntry _compose() => CalendarEntry(
    id: _existing?.id ?? 0,
    date: _date,
    kind: _kind,
    title: _title.text.trim(),
    note: _note.text.trim(),
    startTime: _format(_start),
    endTime: _start == null ? '' : _format(_end),
    repeatIn: _repeat,
    remindDays: _remindDays,
  );

  /// Minutes since midnight, for comparing two times of day.
  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// True when the end is before the start — which the two pickers happily
  /// allow, and which the server then rejects. Catching it here means the
  /// reader is told what to change while the dialog is still in front of them,
  /// instead of after a round trip.
  bool get _endsBeforeItStarts =>
      _start != null && _end != null && _minutes(_end!) < _minutes(_start!);

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      context.showError('A title is required');
      return;
    }
    if (_endsBeforeItStarts) {
      context.showError('The event cannot end before it starts');
      return;
    }
    setState(() => _busy = true);
    try {
      final CalendarEntriesRepository repo = ref.read(
        calendarEntriesRepositoryProvider,
      );
      final CalendarEntry entry = _compose();
      if (_existing != null) {
        await repo.update(entry);
      } else {
        await repo.create(entry);
      }
      ref.invalidate(calendarEntriesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_existing == null ? 'Add event' : 'Edit event'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final CalendarEntryKind k in CalendarEntryKind.values)
                    ChoiceChip(
                      selected: _kind == k,
                      onSelected: (_) => _setKind(k),
                      avatar: Icon(k.icon, size: 15, color: k.color),
                      label: Text(k.label),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                  hintText: switch (_kind) {
                    CalendarEntryKind.birthday => 'Ramesh',
                    CalendarEntryKind.anniversary => 'Wedding',
                    CalendarEntryKind.meeting => 'Sprint review',
                    _ => 'What is it?',
                  },
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _kind == CalendarEntryKind.birthday
                        ? 'Date of birth'
                        : 'Date',
                    isDense: true,
                    prefixIcon: const Icon(Icons.event_outlined, size: 18),
                  ),
                  child: Text(fullDualDate(_date, nepali: false)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fullDualDate(_date, nepali: true),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeField(
                      label: 'Starts',
                      time: _start,
                      onTap: () => _pickTime(start: true),
                      onClear: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Ends',
                      time: _end,
                      enabled: _start != null,
                      onTap: () => _pickTime(start: false),
                      onClear: () => setState(() => _end = null),
                    ),
                  ),
                ],
              ),
              if (_endsBeforeItStarts) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, size: 14, color: scheme.error),
                    const SizedBox(width: 6),
                    Text(
                      'Ends before it starts',
                      style: TextStyle(fontSize: 11.5, color: scheme.error),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<RepeatIn>(
                initialValue: _repeat,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Repeats',
                  isDense: true,
                ),
                items: <DropdownMenuItem<RepeatIn>>[
                  for (final RepeatIn r in RepeatIn.values)
                    DropdownMenuItem<RepeatIn>(
                      value: r,
                      child: Text(r.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (RepeatIn? v) =>
                    setState(() => _repeat = v ?? RepeatIn.none),
              ),
              const SizedBox(height: 4),
              // The two calendars disagree about when "next year" is, and the
              // difference is invisible unless someone says it out loud.
              Text(
                _repeat.hint,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: _remindDays,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Remind me',
                  isDense: true,
                  prefixIcon: Icon(Icons.notifications_outlined, size: 18),
                ),
                items: const <DropdownMenuItem<int?>>[
                  DropdownMenuItem<int?>(value: null, child: Text('Never')),
                  DropdownMenuItem<int?>(value: 0, child: Text('On the day')),
                  DropdownMenuItem<int?>(value: 1, child: Text('1 day before')),
                  DropdownMenuItem<int?>(
                    value: 3,
                    child: Text('3 days before'),
                  ),
                  DropdownMenuItem<int?>(
                    value: 7,
                    child: Text('A week before'),
                  ),
                  DropdownMenuItem<int?>(
                    value: 30,
                    child: Text('A month before'),
                  ),
                ],
                onChanged: (int? v) => setState(() => _remindDays = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _endsBeforeItStarts ? null : _save,
          child: Text(_existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
    required this.onClear,
    this.enabled = true,
  });

  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          enabled: enabled,
          suffixIcon: time == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          time == null
              ? '—'
              : '${time!.hour.toString().padLeft(2, '0')}:'
                    '${time!.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}
