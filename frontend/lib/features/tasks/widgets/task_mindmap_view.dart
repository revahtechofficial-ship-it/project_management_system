import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/task.dart';

const double _nodeW = 170;
const double _nodeH = 36;
const double _stride = 46;
const double _topPad = 16;
final List<double> _colX = <double>[16, 212, 414, 624];

/// A mind-map of the task hierarchy: a root branches to projects, projects to
/// their top-level tasks, and tasks to their subtasks. Pan and zoom the canvas
/// (AGENTS.md §1 feature view). Task nodes are tappable to edit.
class TaskMindMapView extends StatelessWidget {
  const TaskMindMapView({
    super.key,
    required this.tasks,
    required this.onTapTask,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_Node> nodes = <_Node>[];
    final List<(int, int)> edges = <(int, int)>[];

    final List<Task> roots = tasks
        .where((Task t) => t.parentId == null)
        .toList(growable: false);
    if (roots.isEmpty) {
      return Center(
        child: Text(
          'No tasks to map yet.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final Map<String, List<Task>> byProject = <String, List<Task>>{};
    for (final Task t in roots) {
      byProject
          .putIfAbsent(t.projectName ?? 'No project', () => <Task>[])
          .add(t);
    }

    final int rootIndex = nodes.length;
    nodes.add(
      _Node(level: 0, centerY: 0, label: 'All tasks', color: AppColors.brand),
    );

    double y = _topPad;
    int maxLevel = 0;
    final List<double> projectCenters = <double>[];

    for (final MapEntry<String, List<Task>> proj in byProject.entries) {
      final List<double> taskCenters = <double>[];
      final List<int> taskIndexes = <int>[];

      for (final Task t in proj.value) {
        final List<Task> subs = tasks
            .where((Task s) => s.parentId == t.id)
            .toList(growable: false);
        double taskCenter;
        final List<int> subIndexes = <int>[];
        if (subs.isEmpty) {
          taskCenter = y + _nodeH / 2;
          y += _stride;
        } else {
          maxLevel = 3;
          final double firstTop = y;
          for (final Task s in subs) {
            subIndexes.add(nodes.length);
            nodes.add(
              _Node(
                level: 3,
                centerY: y + _nodeH / 2,
                label: s.title,
                color: AppColors.slate,
                task: s,
              ),
            );
            y += _stride;
          }
          taskCenter = (firstTop + (y - _stride)) / 2 + _nodeH / 2;
        }
        final int taskIndex = nodes.length;
        nodes.add(
          _Node(
            level: 2,
            centerY: taskCenter,
            label: t.title,
            color: t.status.color,
            task: t,
          ),
        );
        if (maxLevel < 2) {
          maxLevel = 2;
        }
        taskCenters.add(taskCenter);
        taskIndexes.add(taskIndex);
        for (final int si in subIndexes) {
          edges.add((taskIndex, si));
        }
      }

      final double projCenter = taskCenters.isEmpty
          ? (y + _nodeH / 2)
          : taskCenters.reduce((double a, double b) => a + b) /
                taskCenters.length;
      if (taskCenters.isEmpty) {
        y += _stride;
      }
      final int projIndex = nodes.length;
      nodes.add(
        _Node(
          level: 1,
          centerY: projCenter,
          label: proj.key,
          color: AppColors.violet,
        ),
      );
      if (maxLevel < 1) {
        maxLevel = 1;
      }
      projectCenters.add(projCenter);
      edges.add((rootIndex, projIndex));
      for (final int ti in taskIndexes) {
        edges.add((projIndex, ti));
      }
    }

    final double rootCenter = projectCenters.isEmpty
        ? _topPad + _nodeH / 2
        : projectCenters.reduce((double a, double b) => a + b) /
              projectCenters.length;
    nodes[rootIndex] = nodes[rootIndex].copyWith(centerY: rootCenter);

    final double canvasH = y + _topPad;
    final double canvasW = _colX[maxLevel] + _nodeW + 24;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.4,
      maxScale: 2.0,
      child: SizedBox(
        width: canvasW,
        height: canvasH < 200 ? 200 : canvasH,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(
                  nodes: nodes,
                  edges: edges,
                  color: scheme.outline,
                ),
              ),
            ),
            for (final _Node n in nodes)
              Positioned(
                left: _colX[n.level],
                top: n.centerY - _nodeH / 2,
                child: _NodeChip(
                  node: n,
                  onTap: n.task == null ? null : () => onTapTask(n.task!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Node {
  const _Node({
    required this.level,
    required this.centerY,
    required this.label,
    required this.color,
    this.task,
  });

  final int level;
  final double centerY;
  final String label;
  final Color color;
  final Task? task;

  _Node copyWith({double? centerY}) => _Node(
    level: level,
    centerY: centerY ?? this.centerY,
    label: label,
    color: color,
    task: task,
  );
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({required this.node, required this.onTap});

  final _Node node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _nodeW,
      height: _nodeH,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: node.color, width: 3)),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: node.level <= 1 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.nodes, required this.edges, required this.color});

  final List<_Node> nodes;
  final List<(int, int)> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final (int from, int to) in edges) {
      if (from < 0 || to < 0 || from >= nodes.length || to >= nodes.length) {
        continue;
      }
      final _Node a = nodes[from];
      final _Node b = nodes[to];
      final Offset p1 = Offset(_colX[a.level] + _nodeW, a.centerY);
      final Offset p2 = Offset(_colX[b.level], b.centerY);
      final double midX = (p1.dx + p2.dx) / 2;
      final Path path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(midX, p1.dy, midX, p2.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.nodes != nodes || oldDelegate.edges != edges;
}
