import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/task.dart';
import '../../../data/models/workflow_status.dart';
import '../providers/statuses_providers.dart';

/// A spreadsheet-style view of tasks: sortable-feeling columns in a scrollable
/// data grid. Rows are tappable to edit (AGENTS.md §1 feature view).
class TaskTableView extends ConsumerWidget {
  const TaskTableView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<WorkflowStatus> statuses =
        ref.watch(statusesProvider).asData?.value ?? WorkflowStatus.defaults;
    final DateTime now = DateTime.now();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll<Color>(
                  scheme.surfaceContainerHighest,
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Task')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Assignees')),
                  DataColumn(label: Text('Project')),
                  DataColumn(label: Text('Due')),
                  DataColumn(label: Text('Points'), numeric: true),
                ],
                rows: <DataRow>[
                  for (final Task t in tasks) _row(context, t, statuses, now),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _row(
    BuildContext context,
    Task t,
    List<WorkflowStatus> statuses,
    DateTime now,
  ) {
    final WorkflowStatus ws = WorkflowStatus.forKey(statuses, t.statusKey);
    final bool overdue =
        !t.done && t.dueDate != null && t.dueDate!.toLocal().isBefore(now);
    return DataRow(
      onSelectChanged: (_) => onTapTask(t),
      cells: <DataCell>[
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: t.done ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(StatusPill(label: ws.label, color: ws.color)),
        DataCell(
          t.priority.isSet
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.flag_rounded, size: 14, color: t.priority.color),
                    const SizedBox(width: 4),
                    Text(t.priority.label),
                  ],
                )
              : const Text('—'),
        ),
        DataCell(
          Text(
            t.assigneeNames.isEmpty ? '—' : t.assigneeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text(t.projectName ?? '—')),
        DataCell(
          Text(
            t.dueDate == null ? '—' : shortDate(t.dueDate!.toLocal()),
            style: TextStyle(color: overdue ? AppColors.rose : null),
          ),
        ),
        DataCell(Text(t.points > 0 ? '${t.points}' : '—')),
      ],
    );
  }
}
