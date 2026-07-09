import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/enums/incident_kind.dart';
import '../../../data/enums/incident_severity.dart';
import '../../../data/enums/incident_status.dart';
import '../../../data/models/incident.dart';
import '../../../data/models/project.dart';
import '../../../data/models/team_member.dart';
import '../../../data/repositories/incidents_repository.dart';
import '../../projects/providers/projects_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/incidents_providers.dart';

/// Opens the report/edit dialog for an [Incident]. Pass [existing] to edit;
/// omit it to report a new bug or incident. Returns true when saved.
Future<bool?> showIncidentFormDialog(
  BuildContext context, {
  Incident? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _IncidentFormDialog(existing: existing),
  );
}

class _IncidentFormDialog extends ConsumerStatefulWidget {
  const _IncidentFormDialog({this.existing});
  final Incident? existing;

  @override
  ConsumerState<_IncidentFormDialog> createState() =>
      _IncidentFormDialogState();
}

class _IncidentFormDialogState extends ConsumerState<_IncidentFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _component;
  late final TextEditingController _description;
  late IncidentKind _kind;
  late IncidentSeverity _severity;
  int? _projectId;
  int? _assigneeId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Incident? i = widget.existing;
    _title = TextEditingController(text: i?.title ?? '');
    _component = TextEditingController(text: i?.component ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _kind = i?.kind ?? IncidentKind.bug;
    _severity = i?.severity ?? IncidentSeverity.medium;
    _projectId = i?.projectId;
    _assigneeId = i?.assigneeId;
  }

  @override
  void dispose() {
    _title.dispose();
    _component.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _busy) {
      context.showError('A title is required');
      return;
    }
    setState(() => _busy = true);
    final Incident payload = Incident(
      id: widget.existing?.id ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      status: widget.existing?.status ?? IncidentStatus.open,
      title: _title.text.trim(),
      kind: _kind,
      severity: _severity,
      component: _component.text.trim(),
      description: _description.text.trim(),
      projectId: _projectId,
      assigneeId: _assigneeId,
    );
    try {
      final IncidentsRepository repo = ref.read(incidentsRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      ref.invalidate(incidentsProvider);
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
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final bool editing = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  Icon(_kind.icon, color: _kind.color),
                  const SizedBox(width: 10),
                  Text(
                    editing
                        ? 'Edit issue'
                        : 'Report ${_kind.label.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _title,
                      autofocus: !editing,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<IncidentKind>(
                            initialValue: _kind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<IncidentKind>>[
                              for (final IncidentKind k in IncidentKind.values)
                                DropdownMenuItem<IncidentKind>(
                                  value: k,
                                  child: Text(k.label),
                                ),
                            ],
                            onChanged: (IncidentKind? v) =>
                                setState(() => _kind = v ?? _kind),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<IncidentSeverity>(
                            initialValue: _severity,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Severity',
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<IncidentSeverity>>[
                              for (final IncidentSeverity s
                                  in IncidentSeverity.values)
                                DropdownMenuItem<IncidentSeverity>(
                                  value: s,
                                  child: Text(s.label),
                                ),
                            ],
                            onChanged: (IncidentSeverity? v) =>
                                setState(() => _severity = v ?? _severity),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _component,
                      decoration: const InputDecoration(
                        labelText: 'Component / area (optional)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _projectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Project (optional)',
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(child: Text('No project')),
                        for (final Project p in projects)
                          DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (int? v) => setState(() => _projectId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _assigneeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assignee (optional)',
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(child: Text('Unassigned')),
                        for (final TeamMember m in members)
                          DropdownMenuItem<int?>(
                            value: m.id,
                            child: Text(
                              m.name.isEmpty ? m.email : m.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (int? v) => setState(() => _assigneeId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(editing ? 'Save' : 'Report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
