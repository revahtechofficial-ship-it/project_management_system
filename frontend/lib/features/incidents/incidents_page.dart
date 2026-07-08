import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/csv_export.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/incident_status.dart';
import '../../data/models/incident.dart';
import 'providers/incidents_providers.dart';
import 'widgets/incident_form_dialog.dart';

/// Incidents: the bug and incident tracker with a severity + triage workflow.
class IncidentsPage extends ConsumerStatefulWidget {
  const IncidentsPage({super.key});

  @override
  ConsumerState<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends ConsumerState<IncidentsPage> {
  IncidentStatus? _filter;

  Future<void> _report() async {
    await showIncidentFormDialog(context);
  }

  void _export() {
    final List<Incident> items =
        ref.read(incidentsProvider).asData?.value ?? const <Incident>[];
    if (items.isEmpty) {
      context.showError('Nothing to export');
      return;
    }
    exportCsv(
      'incidents',
      <String>[
        'Title', 'Type', 'Severity', 'Status', 'Assignee', 'Reporter',
        'Project', 'Component', 'Created',
      ],
      <List<String>>[
        for (final Incident i in items)
          <String>[
            i.title,
            i.kind.label,
            i.severity.label,
            i.status.label,
            i.assigneeName,
            i.reporterName,
            i.projectName,
            i.component,
            dateParam(i.createdAt) ?? '',
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Incident>> async = ref.watch(incidentsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Incidents',
            subtitle: 'Bugs & incidents',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export'),
              ),
              FilledButton.icon(
                onPressed: _report,
                icon: const Icon(Icons.add),
                label: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(incidentsProvider),
              ),
              data: (List<Incident> all) => _Body(
                all: all,
                filter: _filter,
                onFilter: (IncidentStatus? s) => setState(() => _filter = s),
                onReport: _report,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.all,
    required this.filter,
    required this.onFilter,
    required this.onReport,
  });

  final List<Incident> all;
  final IncidentStatus? filter;
  final ValueChanged<IncidentStatus?> onFilter;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.bug_report_outlined,
        title: 'No issues logged',
        message: 'Report a bug or incident to track it through triage to '
            'resolution.',
        actionLabel: 'Report an issue',
        actionIcon: Icons.add,
        onAction: onReport,
      );
    }
    final List<Incident> items = filter == null
        ? all
        : all.where((Incident i) => i.status == filter).toList();
    final int active = all.where((Incident i) => i.status.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _Stat(label: '$active active', icon: Icons.error_outline),
            _Stat(
              label: '${all.length} total',
              icon: Icons.all_inbox_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FilterBar(selected: filter, onSelect: onFilter),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int i) =>
                _IncidentRow(incident: items[i]),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final IncidentStatus? selected;
  final ValueChanged<IncidentStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final IncidentStatus s in IncidentStatus.values)
          ChoiceChip(
            label: Text(s.label),
            selected: selected == s,
            onSelected: (_) => onSelect(s),
          ),
      ],
    );
  }
}

class _IncidentRow extends ConsumerWidget {
  const _IncidentRow({required this.incident});
  final Incident incident;

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, IncidentStatus status) async {
    try {
      await ref
          .read(incidentsRepositoryProvider)
          .setStatus(incident.id, status.toJson());
      ref.invalidate(incidentsProvider);
      if (context.mounted) {
        context.showSuccess('Marked ${status.label.toLowerCase()}');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update: $e');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete issue?'),
            content: Text('Remove "${incident.title}" permanently?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(incidentsRepositoryProvider).delete(incident.id);
      ref.invalidate(incidentsProvider);
      if (context.mounted) {
        context.showSuccess('Issue deleted');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  /// Workflow transitions available from the current status.
  List<IncidentStatus> get _transitions => switch (incident.status) {
        IncidentStatus.open => <IncidentStatus>[
            IncidentStatus.investigating,
            IncidentStatus.resolved,
            IncidentStatus.closed,
          ],
        IncidentStatus.investigating => <IncidentStatus>[
            IncidentStatus.mitigated,
            IncidentStatus.resolved,
            IncidentStatus.closed,
          ],
        IncidentStatus.mitigated => <IncidentStatus>[
            IncidentStatus.resolved,
            IncidentStatus.closed,
          ],
        IncidentStatus.resolved => <IncidentStatus>[
            IncidentStatus.closed,
            IncidentStatus.open,
          ],
        IncidentStatus.closed => <IncidentStatus>[IncidentStatus.open],
      };

  String _labelFor(IncidentStatus s) =>
      s == IncidentStatus.open ? 'Re-open' : 'Mark ${s.label.toLowerCase()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Incident i = incident;
    final List<String> meta = <String>[
      if (i.component.isNotEmpty) i.component,
      if (i.projectName.isNotEmpty) i.projectName,
      if (i.reporterName.isNotEmpty) 'by ${i.reporterName}',
      relativeTime(i.createdAt),
    ];
    return DashboardCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SeverityBadge(incident: i),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(i.kind.icon, size: 15, color: i.kind.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  meta.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (i.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    i.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _StatusChip(status: i.status),
              if (i.assigneeId != null) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    UserAvatar(name: i.assigneeName, radius: 10),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        i.assigneeName.isEmpty ? 'Assigned' : i.assigneeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_horiz),
            onSelected: (String v) {
              switch (v) {
                case 'edit':
                  showIncidentFormDialog(context, existing: i);
                case 'delete':
                  _delete(context, ref);
                default:
                  _setStatus(context, ref, IncidentStatus.fromJson(v));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              for (final IncidentStatus s in _transitions)
                PopupMenuItem<String>(
                  value: s.toJson(),
                  child: Text(_labelFor(s)),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              const PopupMenuItem<String>(
                  value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final Color color = incident.severity.color;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.priority_high, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            incident.severity.label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
