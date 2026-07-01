import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/task.dart';
import '../../../data/models/workflow_status.dart';
import '../providers/statuses_providers.dart';
import '../providers/tasks_providers.dart';

/// A Kanban board: one column per workflow status. Drag a card to another
/// column to change its status (persisted; `done` stays in sync server-side).
class TaskBoardView extends ConsumerWidget {
  const TaskBoardView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final void Function(Task) onTapTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<WorkflowStatus> loaded =
        ref.watch(statusesProvider).asData?.value ?? const <WorkflowStatus>[];
    final List<WorkflowStatus> statuses = loaded.isEmpty
        ? WorkflowStatus.defaults
        : loaded;

    Future<void> move(Task t, String statusKey) async {
      if (t.statusKey == statusKey) {
        return;
      }
      await ref.read(tasksRepositoryProvider).setStatusKey(t.id, statusKey);
      ref.invalidate(tasksProvider);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final WorkflowStatus status in statuses)
            SizedBox(
              width: 284,
              child: _BoardColumn(
                status: status,
                tasks: tasks
                    .where((Task t) => t.statusKey == status.key)
                    .toList(growable: false),
                onTapTask: onTapTask,
                onDropTask: (Task t) => move(t, status.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.tasks,
    required this.onTapTask,
    required this.onDropTask,
  });

  final WorkflowStatus status;
  final List<Task> tasks;
  final void Function(Task) onTapTask;
  final void Function(Task) onDropTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onAcceptWithDetails: (DragTargetDetails<Task> d) =>
                  onDropTask(d.data),
              builder:
                  (
                    BuildContext context,
                    List<Task?> candidate,
                    List<dynamic> rejected,
                  ) {
                    final bool active = candidate.isNotEmpty;
                    return Container(
                      decoration: BoxDecoration(
                        color: active
                            ? status.color.withValues(alpha: 0.08)
                            : scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? status.color : scheme.outlineVariant,
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: tasks.isEmpty
                          ? Center(
                              child: Text(
                                'Drop tasks here',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: <Widget>[
                                for (final Task t in tasks)
                                  _BoardCard(
                                    task: t,
                                    accent: status.color,
                                    onTap: onTapTask,
                                  ),
                              ],
                            ),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.task,
    required this.accent,
    required this.onTap,
  });
  final Task task;
  final Color accent;
  final void Function(Task) onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = _CardBody(task: task, accent: accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Draggable<Task>(
        data: task,
        // A slightly rotated, scaled, shadowed card reads as "lifted".
        feedback: Transform.rotate(
          angle: 0.02,
          child: Transform.scale(
            scale: 1.03,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 256,
                child: _CardBody(task: task, accent: accent, dragging: true),
              ),
            ),
          ),
        ),
        childWhenDragging: const _DropPlaceholder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onTap(task),
          child: card,
        ),
      ),
    );
  }
}

/// The dashed outline left in a column while its card is being dragged.
class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      child: const SizedBox(height: 56, width: double.infinity),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(10),
        ),
      );
    const double dash = 6;
    const double gap = 4;
    for (final PathMetric metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.task,
    required this.accent,
    this.dragging = false,
  });
  final Task task;
  final Color accent;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool overdue =
        !task.done &&
        task.dueDate != null &&
        task.dueDate!.toLocal().isBefore(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: dragging
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.projectName != null ||
                          task.assigneeName != null ||
                          task.dueDate != null ||
                          task.subtaskCount > 0 ||
                          task.recurrence.repeats ||
                          task.priority.isSet ||
                          task.tags.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            if (task.priority.isSet)
                              _MiniChip(
                                icon: Icons.flag_rounded,
                                label: task.priority.label,
                                color: task.priority.color,
                              ),
                            if (task.projectName != null)
                              _MiniChip(
                                icon: Icons.folder_outlined,
                                label: task.projectName!,
                                color: AppColors.brand,
                              ),
                            if (task.assigneeNames.isNotEmpty)
                              AvatarStack(
                                names: task.assigneeNames,
                                radius: 9,
                                max: 3,
                              ),
                            if (task.dueDate != null)
                              _MiniChip(
                                icon: Icons.event,
                                label: shortDate(task.dueDate!.toLocal()),
                                color: overdue
                                    ? AppColors.rose
                                    : AppColors.slate,
                              ),
                            if (task.subtaskCount > 0)
                              _MiniChip(
                                icon: Icons.checklist_rounded,
                                label:
                                    '${task.subtaskDoneCount}/${task.subtaskCount}',
                                color: AppColors.violet,
                              ),
                            if (task.recurrence.repeats)
                              _MiniChip(
                                icon: Icons.repeat,
                                label: task.recurrence.label,
                                color: AppColors.slate,
                              ),
                            for (final String tag in task.tags.take(3))
                              StatusPill(label: tag, color: avatarColor(tag)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      AppChip(icon: icon, label: label, color: color);
}
