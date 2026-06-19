import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/objective_status.dart';
import '../../../data/models/objective.dart';
import '../../../data/models/team_member.dart';
import '../../team/providers/team_providers.dart';
import '../providers/goals_providers.dart';

/// Opens the create/edit dialog for an objective. Returns true if saved.
Future<bool?> showObjectiveDialog(
  BuildContext context, {
  Objective? existing,
  required List<Objective> objectives,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        _ObjectiveDialog(existing: existing, objectives: objectives),
  );
}

class _ObjectiveDialog extends ConsumerStatefulWidget {
  const _ObjectiveDialog({this.existing, required this.objectives});

  final Objective? existing;
  final List<Objective> objectives;

  @override
  ConsumerState<_ObjectiveDialog> createState() => _ObjectiveDialogState();
}

class _ObjectiveDialogState extends ConsumerState<_ObjectiveDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _period = TextEditingController(
    text: widget.existing?.period ?? '',
  );
  late int? _ownerId = widget.existing?.ownerId;
  late int? _parentId = widget.existing?.parentId;
  late ObjectiveStatus _status =
      widget.existing?.status == null ||
          widget.existing!.status == ObjectiveStatus.unknown
      ? ObjectiveStatus.active
      : widget.existing!.status;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'A title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(objectivesRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          ownerId: _ownerId,
          parentId: _parentId,
          period: _period.text.trim(),
          status: _status.toJson(),
        );
      } else {
        await repo.create(
          title: _title.text.trim(),
          description: _desc.text.trim(),
          ownerId: _ownerId,
          parentId: _parentId,
          period: _period.text.trim(),
          status: _status.toJson(),
        );
      }
      ref.invalidate(objectivesProvider);
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
    final List<TeamMember> team =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final List<Objective> parents = widget.objectives
        .where((Objective o) => o.id != widget.existing?.id)
        .toList(growable: false);
    return AlertDialog(
      title: Text(_isEdit ? 'Edit objective' : 'New objective'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Objective'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _period,
                      decoration: const InputDecoration(
                        labelText: 'Period',
                        hintText: 'e.g. Q3 2026',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ObjectiveStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<ObjectiveStatus>>[
                        for (final ObjectiveStatus s
                            in ObjectiveStatus.selectable)
                          DropdownMenuItem<ObjectiveStatus>(
                            value: s,
                            child: Text(s.label),
                          ),
                      ],
                      onChanged: (ObjectiveStatus? v) =>
                          setState(() => _status = v ?? ObjectiveStatus.active),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: team.any((TeamMember m) => m.id == _ownerId)
                    ? _ownerId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  isDense: true,
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('No owner'),
                  ),
                  for (final TeamMember m in team)
                    DropdownMenuItem<int?>(
                      value: m.id,
                      child: Text(m.name.isEmpty ? m.email : m.name),
                    ),
                ],
                onChanged: (int? v) => setState(() => _ownerId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: parents.any((Objective o) => o.id == _parentId)
                    ? _parentId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Aligns to (parent objective)',
                  isDense: true,
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Top-level (no parent)'),
                  ),
                  for (final Objective o in parents)
                    DropdownMenuItem<int?>(
                      value: o.id,
                      child: Text(o.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (int? v) => setState(() => _parentId = v),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
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
