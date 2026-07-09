import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/csv_export.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/report_def.dart';
import '../../data/models/task.dart';
import '../../data/repositories/reports_repository.dart';
import '../tasks/providers/tasks_providers.dart';
import 'providers/reports_providers.dart';

/// The reportable fields on a task: (key, label).
const List<(String, String)> _fields = <(String, String)>[
  ('title', 'Title'),
  ('status', 'Status'),
  ('priority', 'Priority'),
  ('project', 'Project'),
  ('assignee', 'Assignee'),
  ('done', 'Done'),
  ('due', 'Due date'),
  ('created', 'Created'),
  ('tags', 'Tags'),
  ('points', 'Points'),
  ('estimate', 'Estimate (h)'),
];

const List<(String, String)> _ops = <(String, String)>[
  ('is', 'is'),
  ('is_not', 'is not'),
  ('contains', 'contains'),
];

String _fieldLabel(String key) {
  for (final (String, String) f in _fields) {
    if (f.$1 == key) {
      return f.$2;
    }
  }
  return key;
}

String _fieldValue(Task t, String key) => switch (key) {
  'title' => t.title,
  'status' => t.status.label,
  'priority' => t.priority.label,
  'project' => t.projectName ?? '',
  'assignee' => t.assigneeName ?? '',
  'done' => t.done ? 'Yes' : 'No',
  'due' =>
    t.dueDate == null ? '' : '${shortDate(t.dueDate!)} ${t.dueDate!.year}',
  'created' => '${shortDate(t.createdAt)} ${t.createdAt.year}',
  'tags' => t.tags.join(', '),
  'points' => '${t.points}',
  'estimate' => (t.estimateMinutes / 60).toStringAsFixed(1),
  _ => '',
};

bool _matches(Task t, List<ReportFilter> filters) {
  for (final ReportFilter f in filters) {
    if (f.value.trim().isEmpty) {
      continue;
    }
    final String actual = _fieldValue(t, f.field).toLowerCase();
    final String val = f.value.trim().toLowerCase();
    switch (f.op) {
      case 'is_not':
        if (actual == val) return false;
      case 'contains':
        if (!actual.contains(val)) return false;
      default:
        if (actual != val) return false;
    }
  }
  return true;
}

/// Report builder: pick columns and filters over tasks, preview the table,
/// save the definition and export to CSV.
class ReportBuilderPage extends ConsumerStatefulWidget {
  const ReportBuilderPage({super.key});

  @override
  ConsumerState<ReportBuilderPage> createState() => _ReportBuilderPageState();
}

class _ReportBuilderPageState extends ConsumerState<ReportBuilderPage> {
  final TextEditingController _name = TextEditingController();
  final List<String> _columns = <String>[
    'title',
    'status',
    'priority',
    'assignee',
  ];
  final List<ReportFilter> _filters = <ReportFilter>[];
  int? _reportId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Selected columns in catalog order.
  List<String> get _orderedColumns => <String>[
    for (final (String, String) f in _fields)
      if (_columns.contains(f.$1)) f.$1,
  ];

  List<Task> _filtered(List<Task> all) => <Task>[
    for (final Task t in all)
      if (_matches(t, _filters)) t,
  ];

  void _loadReport(ReportDef r) {
    setState(() {
      _reportId = r.id;
      _name.text = r.name;
      _columns
        ..clear()
        ..addAll(r.columns.isEmpty ? <String>['title'] : r.columns);
      _filters
        ..clear()
        ..addAll(r.filters);
    });
  }

  void _reset() {
    setState(() {
      _reportId = null;
      _name.clear();
      _columns
        ..clear()
        ..addAll(<String>['title', 'status', 'priority', 'assignee']);
      _filters.clear();
    });
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      context.showError('Name the report first');
      return;
    }
    if (_orderedColumns.isEmpty) {
      context.showError('Pick at least one column');
      return;
    }
    try {
      final ReportsRepository repo = ref.read(reportsRepositoryProvider);
      if (_reportId == null) {
        final ReportDef r = await repo.create(
          name: name,
          columns: _orderedColumns,
          filters: _filters,
        );
        _reportId = r.id;
      } else {
        await repo.update(
          _reportId!,
          name: name,
          columns: _orderedColumns,
          filters: _filters,
        );
      }
      ref.invalidate(savedReportsProvider);
      if (mounted) {
        context.showSuccess('Report saved');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not save: $e');
      }
    }
  }

  void _export(List<Task> all) {
    final List<String> cols = _orderedColumns;
    if (cols.isEmpty) {
      context.showError('Pick at least one column');
      return;
    }
    final List<Task> rows = _filtered(all);
    exportCsv(
      _name.text.trim().isEmpty ? 'report' : _name.text.trim(),
      <String>[for (final String c in cols) _fieldLabel(c)],
      <List<String>>[
        for (final Task t in rows)
          <String>[for (final String c in cols) _fieldValue(t, c)],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Task>> tasks = ref.watch(tasksProvider);
    final List<ReportDef> saved =
        ref.watch(savedReportsProvider).asData?.value ?? const <ReportDef>[];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Report builder',
            subtitle: 'Filter tasks, pick columns, save & export',
            actions: <Widget>[
              if (saved.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: 'Load a saved report',
                  onSelected: (int id) {
                    for (final ReportDef r in saved) {
                      if (r.id == id) {
                        _loadReport(r);
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                    for (final ReportDef r in saved)
                      PopupMenuItem<int>(value: r.id, child: Text(r.name)),
                  ],
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Saved'),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
              OutlinedButton.icon(
                onPressed: tasks.asData == null
                    ? null
                    : () => _export(tasks.asData!.value),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export'),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ConfigCard(
            name: _name,
            columns: _columns,
            filters: _filters,
            reportId: _reportId,
            onDeleted: _reset,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasks.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(tasksProvider),
              ),
              data: (List<Task> all) =>
                  _Results(rows: _filtered(all), columns: _orderedColumns),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends ConsumerWidget {
  const _ConfigCard({
    required this.name,
    required this.columns,
    required this.filters,
    required this.reportId,
    required this.onDeleted,
    required this.onChanged,
  });

  final TextEditingController name;
  final List<String> columns;
  final List<ReportFilter> filters;
  final int? reportId;
  final VoidCallback onDeleted;
  final VoidCallback onChanged;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (reportId == null) {
      return;
    }
    try {
      await ref.read(reportsRepositoryProvider).delete(reportId!);
      ref.invalidate(savedReportsProvider);
      onDeleted();
      if (context.mounted) {
        context.showSuccess('Report deleted');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Report name',
                    isDense: true,
                  ),
                ),
              ),
              if (reportId != null)
                IconButton(
                  tooltip: 'Delete report',
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _delete(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Columns',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (String, String) f in _fields)
                FilterChip(
                  label: Text(f.$2),
                  selected: columns.contains(f.$1),
                  onSelected: (bool on) {
                    if (on) {
                      columns.add(f.$1);
                    } else {
                      columns.remove(f.$1);
                    }
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Filters',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < filters.length; i++)
            _FilterRow(
              filter: filters[i],
              onChanged: (ReportFilter f) {
                filters[i] = f;
                onChanged();
              },
              onRemove: () {
                filters.removeAt(i);
                onChanged();
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                filters.add(const ReportFilter());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add filter'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.onChanged,
    required this.onRemove,
  });

  final ReportFilter filter;
  final ValueChanged<ReportFilter> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: filter.field,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: <DropdownMenuItem<String>>[
                for (final (String, String) f in _fields)
                  DropdownMenuItem<String>(value: f.$1, child: Text(f.$2)),
              ],
              onChanged: (String? v) =>
                  onChanged(filter.copyWith(field: v ?? filter.field)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: filter.op,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: <DropdownMenuItem<String>>[
                for (final (String, String) o in _ops)
                  DropdownMenuItem<String>(value: o.$1, child: Text(o.$2)),
              ],
              onChanged: (String? v) =>
                  onChanged(filter.copyWith(op: v ?? filter.op)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _ValueField(
              value: filter.value,
              onChanged: (String v) => onChanged(filter.copyWith(value: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A text input that preserves its cursor across parent rebuilds.
class _ValueField extends StatefulWidget {
  const _ValueField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      decoration: const InputDecoration(isDense: true, hintText: 'Value'),
      onChanged: widget.onChanged,
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.rows, required this.columns});
  final List<Task> rows;
  final List<String> columns;

  static const int _cap = 300;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (columns.isEmpty) {
      return const EmptyState(
        icon: Icons.view_column_outlined,
        title: 'Pick some columns',
        message: 'Choose which task fields to show in the report.',
      );
    }
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.filter_alt_outlined,
        title: 'No matching tasks',
        message: 'No tasks match the current filters.',
      );
    }
    final List<Task> shown = rows.take(_cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            rows.length > _cap
                ? '${rows.length} tasks · showing first $_cap (export for all)'
                : '${rows.length} ${rows.length == 1 ? 'task' : 'tasks'}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: <DataColumn>[
                  for (final String c in columns)
                    DataColumn(label: Text(_fieldLabel(c))),
                ],
                rows: <DataRow>[
                  for (final Task t in shown)
                    DataRow(
                      cells: <DataCell>[
                        for (final String c in columns)
                          DataCell(Text(_fieldValue(t, c))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
