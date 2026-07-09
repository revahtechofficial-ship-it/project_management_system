import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../providers/patro_providers.dart';

/// Opens the add-holiday dialog for [initialDate]. Returns true when saved.
Future<bool?> showAddHolidayDialog(BuildContext context, DateTime initialDate) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _AddHolidayDialog(initialDate: initialDate),
  );
}

class _AddHolidayDialog extends ConsumerStatefulWidget {
  const _AddHolidayDialog({required this.initialDate});
  final DateTime initialDate;

  @override
  ConsumerState<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends ConsumerState<_AddHolidayDialog> {
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _nameNe = TextEditingController();
  late DateTime _date = dateOnly(widget.initialDate);
  bool _isPublic = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameEn.dispose();
    _nameNe.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (_nameEn.text.trim().isEmpty) {
      context.showError('An English name is required');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(holidaysRepositoryProvider)
          .create(
            date: _date,
            nameEn: _nameEn.text.trim(),
            nameNe: _nameNe.text.trim(),
            isPublic: _isPublic,
          );
      ref.invalidate(holidaysProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add holiday'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  isDense: true,
                  prefixIcon: Icon(Icons.event_outlined, size: 18),
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
            TextField(
              controller: _nameEn,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name (English)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameNe,
              decoration: const InputDecoration(
                labelText: 'नाम (नेपाली)',
                isDense: true,
                hintText: 'दशैं',
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              title: const Text('Public holiday'),
              subtitle: const Text('Office closed'),
              onChanged: (bool? v) => setState(() => _isPublic = v ?? true),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Add')),
      ],
    );
  }
}
