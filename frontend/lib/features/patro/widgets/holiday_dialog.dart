import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/festival_category.dart';
import '../../../data/models/holiday.dart';
import '../../../data/repositories/holidays_repository.dart';
import '../providers/patro_providers.dart';

/// Opens the holiday editor. Pass [existing] to edit one, or [initialDate] to
/// add a new one. Returns true when saved.
Future<bool?> showHolidayDialog(
  BuildContext context, {
  DateTime? initialDate,
  Holiday? existing,
}) {
  assert(
    initialDate != null || existing != null,
    'needs either a date to add on, or a holiday to edit',
  );
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) =>
        _HolidayDialog(initialDate: initialDate, existing: existing),
  );
}

class _HolidayDialog extends ConsumerStatefulWidget {
  const _HolidayDialog({this.initialDate, this.existing});

  final DateTime? initialDate;
  final Holiday? existing;

  @override
  ConsumerState<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends ConsumerState<_HolidayDialog> {
  late final Holiday? _existing = widget.existing;

  late final TextEditingController _nameEn = TextEditingController(
    text: _existing?.nameEn ?? '',
  );
  late final TextEditingController _nameNe = TextEditingController(
    text: _existing?.nameNe ?? '',
  );
  late final TextEditingController _descEn = TextEditingController(
    text: _existing?.description.en ?? '',
  );
  late final TextEditingController _descNe = TextEditingController(
    text: _existing?.description.ne ?? '',
  );
  late final TextEditingController _historyEn = TextEditingController(
    text: _existing?.history.en ?? '',
  );
  late final TextEditingController _historyNe = TextEditingController(
    text: _existing?.history.ne ?? '',
  );
  late final TextEditingController _importanceEn = TextEditingController(
    text: _existing?.importance.en ?? '',
  );
  late final TextEditingController _importanceNe = TextEditingController(
    text: _existing?.importance.ne ?? '',
  );
  late final TextEditingController _celebrationEn = TextEditingController(
    text: _existing?.celebration.en ?? '',
  );
  late final TextEditingController _celebrationNe = TextEditingController(
    text: _existing?.celebration.ne ?? '',
  );

  late DateTime _date = dateOnly(
    _existing?.date ?? widget.initialDate ?? DateTime.now(),
  );
  late FestivalCategory _category =
      _existing?.category ?? FestivalCategory.other;
  late bool _isPublic = _existing?.isPublic ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _nameEn,
      _nameNe,
      _descEn,
      _descNe,
      _historyEn,
      _historyNe,
      _importanceEn,
      _importanceNe,
      _celebrationEn,
      _celebrationNe,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 10),
      lastDate: DateTime(_date.year + 10),
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Holiday _compose() => Holiday(
    id: _existing?.id ?? 0,
    date: _date,
    nameEn: _nameEn.text.trim(),
    nameNe: _nameNe.text.trim(),
    isPublic: _isPublic,
    category: _category,
    description: Bilingual(en: _descEn.text.trim(), ne: _descNe.text.trim()),
    history: Bilingual(en: _historyEn.text.trim(), ne: _historyNe.text.trim()),
    importance: Bilingual(
      en: _importanceEn.text.trim(),
      ne: _importanceNe.text.trim(),
    ),
    celebration: Bilingual(
      en: _celebrationEn.text.trim(),
      ne: _celebrationNe.text.trim(),
    ),
  );

  Future<void> _save() async {
    if (_nameEn.text.trim().isEmpty) {
      context.showError('An English name is required');
      return;
    }
    setState(() => _busy = true);
    try {
      final HolidaysRepository repo = ref.read(holidaysRepositoryProvider);
      final Holiday holiday = _compose();
      if (_existing != null) {
        await repo.update(holiday);
      } else {
        await repo.create(holiday);
      }
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
      title: Text(_existing == null ? 'Add holiday' : 'Edit holiday'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _nameEn,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Name (English)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameNe,
                      decoration: const InputDecoration(
                        labelText: 'नाम (नेपाली)',
                        isDense: true,
                        hintText: 'दशैं',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FestivalCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                ),
                items: <DropdownMenuItem<FestivalCategory>>[
                  for (final FestivalCategory c in FestivalCategory.values)
                    DropdownMenuItem<FestivalCategory>(
                      value: c,
                      child: Row(
                        children: <Widget>[
                          Icon(c.icon, size: 16, color: c.color),
                          const SizedBox(width: 8),
                          Text('${c.label} · ${c.labelNe}'),
                        ],
                      ),
                    ),
                ],
                onChanged: (FestivalCategory? v) =>
                    setState(() => _category = v ?? FestivalCategory.other),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPublic,
                title: const Text('Public holiday'),
                subtitle: const Text('Office closed nationwide'),
                onChanged: (bool? v) => setState(() => _isPublic = v ?? true),
              ),
              const Divider(height: 20),
              _ProseField(
                label: 'About',
                hint: 'What this day is, in a sentence or two.',
                en: _descEn,
                ne: _descNe,
              ),
              _ProseField(
                label: 'History',
                hint: 'Where it comes from.',
                en: _historyEn,
                ne: _historyNe,
              ),
              _ProseField(
                label: 'Importance',
                hint: 'Why it matters.',
                en: _importanceEn,
                ne: _importanceNe,
              ),
              _ProseField(
                label: 'How it is celebrated',
                hint: 'What people do.',
                en: _celebrationEn,
                ne: _celebrationNe,
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
          onPressed: _busy ? null : _save,
          child: Text(_existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

/// One section of festival prose, English above Nepali. Either may be blank —
/// the reader falls back to whichever is filled in.
class _ProseField extends StatelessWidget {
  const _ProseField({
    required this.label,
    required this.hint,
    required this.en,
    required this.ne,
  });

  final String label;
  final String hint;
  final TextEditingController en;
  final TextEditingController ne;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: en,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'English',
              hintText: hint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ne,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'नेपाली',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
