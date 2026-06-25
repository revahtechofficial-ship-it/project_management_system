import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/enums/availability_kind.dart';
import '../../../data/models/team_member.dart';
import '../../team/providers/team_providers.dart';
import '../providers/resources_providers.dart';

/// Opens the "add time off" dialog. Returns true when an entry was saved.
Future<bool?> showTimeOffDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (BuildContext context) => const _TimeOffDialog(),
);

class _TimeOffDialog extends ConsumerStatefulWidget {
  const _TimeOffDialog();

  @override
  ConsumerState<_TimeOffDialog> createState() => _TimeOffDialogState();
}

class _TimeOffDialogState extends ConsumerState<_TimeOffDialog> {
  int? _userId;
  AvailabilityKind _kind = AvailabilityKind.vacation;
  late DateTime _start = _today();
  late DateTime _end = _today();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(_today().year - 1),
      lastDate: DateTime(_today().year + 2),
    );
    if (d != null) {
      setState(() {
        _start = DateTime(d.year, d.month, d.day);
        if (_end.isBefore(_start)) {
          _end = _start;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime(_today().year + 2),
    );
    if (d != null) {
      setState(() => _end = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _save() async {
    if (_userId == null) {
      setState(() => _error = 'Pick a team member');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(resourcesRepositoryProvider)
          .addAvailability(
            userId: _userId!,
            start: _start,
            end: _end,
            kind: _kind,
            note: _note.text.trim(),
          );
      ref.invalidate(availabilityProvider);
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
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    return AlertDialog(
      title: const Text('Add time off'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _userId,
              decoration: const InputDecoration(labelText: 'Team member'),
              items: <DropdownMenuItem<int>>[
                for (final TeamMember m in members)
                  DropdownMenuItem<int>(
                    value: m.id,
                    child: Text(m.name.isEmpty ? m.email : m.name),
                  ),
              ],
              onChanged: (int? v) => setState(() => _userId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AvailabilityKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<AvailabilityKind>>[
                for (final AvailabilityKind k in AvailabilityKind.selectable)
                  DropdownMenuItem<AvailabilityKind>(
                    value: k,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(k.icon, size: 18, color: k.color),
                        const SizedBox(width: 8),
                        Text(k.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (AvailabilityKind? k) =>
                  setState(() => _kind = k ?? AvailabilityKind.other),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _start,
                    onTap: _pickStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(label: 'To', value: _end, onTap: _pickEnd),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. annual leave',
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(shortDate(value)),
      ),
    );
  }
}
