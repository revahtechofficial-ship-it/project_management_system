import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/milestone.dart';
import '../../../providers/auth_provider.dart';
import '../providers/milestones_providers.dart';

/// Add / toggle / delete workspace milestones. Changes hit the API immediately
/// and refresh the [milestonesProvider].
class MilestonesDialog extends ConsumerStatefulWidget {
  const MilestonesDialog({super.key});

  @override
  ConsumerState<MilestonesDialog> createState() => _MilestonesDialogState();
}

class _MilestonesDialogState extends ConsumerState<MilestonesDialog> {
  final TextEditingController _name = TextEditingController();
  DateTime? _date;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(milestonesProvider);

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _add() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _date == null) {
      setState(() => _error = 'Enter a name and pick a date');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(milestonesRepositoryProvider)
          .create(name: name, dueDate: _date!);
      _name.clear();
      setState(() {
        _busy = false;
        _date = null;
      });
      _refresh();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggle(Milestone m) async {
    await ref
        .read(milestonesRepositoryProvider)
        .update(m.id, name: m.name, dueDate: m.dueDate, done: !m.done);
    _refresh();
  }

  Future<void> _remove(int id) async {
    await ref.read(milestonesRepositoryProvider).delete(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Milestone> items =
        ref.watch(milestonesProvider).asData?.value ?? const <Milestone>[];
    final bool isAdmin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;

    return AlertDialog(
      title: const Text('Milestones'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (items.isEmpty)
              Text(
                'No milestones yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final Milestone m in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.flag,
                          color: m.done ? AppColors.green : AppColors.rose,
                        ),
                        title: Text(
                          m.name,
                          style: TextStyle(
                            decoration: m.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(shortDate(m.dueDate)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Checkbox(
                              value: m.done,
                              onChanged: (_) => _toggle(m),
                            ),
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _remove(m.id),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Milestone name',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_date == null ? 'Date' : shortDate(_date!)),
                ),
                IconButton(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  onPressed: _busy ? null : _add,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
