import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/key_result.dart';
import '../providers/goals_providers.dart';

/// Opens the add/edit dialog for a key result. Returns true if saved.
Future<bool?> showKeyResultDialog(
  BuildContext context, {
  required int objectiveId,
  KeyResult? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        _KeyResultDialog(objectiveId: objectiveId, existing: existing),
  );
}

class _KeyResultDialog extends ConsumerStatefulWidget {
  const _KeyResultDialog({required this.objectiveId, this.existing});

  final int objectiveId;
  final KeyResult? existing;

  @override
  ConsumerState<_KeyResultDialog> createState() => _KeyResultDialogState();
}

class _KeyResultDialogState extends ConsumerState<_KeyResultDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _start = TextEditingController(
    text: widget.existing == null ? '0' : _fmt(widget.existing!.startValue),
  );
  late final TextEditingController _current = TextEditingController(
    text: widget.existing == null ? '0' : _fmt(widget.existing!.currentValue),
  );
  late final TextEditingController _target = TextEditingController(
    text: widget.existing == null ? '100' : _fmt(widget.existing!.targetValue),
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.existing?.unit ?? '',
  );
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _title.dispose();
    _start.dispose();
    _current.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return;
    }
    final double start = double.tryParse(_start.text.trim()) ?? 0;
    final double current = double.tryParse(_current.text.trim()) ?? 0;
    final double target = double.tryParse(_target.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      final repo = ref.read(objectivesRepositoryProvider);
      if (_isEdit) {
        await repo.updateKeyResult(
          widget.existing!.id,
          title: _title.text.trim(),
          startValue: start,
          currentValue: current,
          targetValue: target,
          unit: _unit.text.trim(),
        );
      } else {
        await repo.addKeyResult(
          widget.objectiveId,
          title: _title.text.trim(),
          startValue: start,
          currentValue: current,
          targetValue: target,
          unit: _unit.text.trim(),
        );
      }
      ref.invalidate(objectivesProvider);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Widget _num(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit key result' : 'Add key result'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Key result'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _num(_start, 'Start'),
                const SizedBox(width: 10),
                _num(_current, 'Current'),
                const SizedBox(width: 10),
                _num(_target, 'Target'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'e.g. %, users, \$',
                isDense: true,
              ),
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
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
