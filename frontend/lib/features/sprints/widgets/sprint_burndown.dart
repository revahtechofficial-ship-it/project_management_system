import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/sprint.dart';
import '../../../data/models/task.dart';

/// A burndown chart for a sprint: remaining story points per day (derived from
/// task completion times) against the ideal straight-line burndown. Needs the
/// sprint's start and end dates plus story points to render (AGENTS.md §1).
class SprintBurndown extends StatelessWidget {
  const SprintBurndown({super.key, required this.sprint, required this.tasks});

  final Sprint sprint;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (sprint.startDate == null || sprint.endDate == null) {
      return _hint(scheme, 'Set a start and end date to see the burndown.');
    }
    final List<Task> sprintTasks = tasks
        .where((Task t) => t.sprintId == sprint.id && t.parentId == null)
        .toList(growable: false);
    final int total = sprintTasks.fold<int>(0, (int s, Task t) => s + t.points);
    if (total == 0) {
      return _hint(scheme, 'Add story points to tasks to see the burndown.');
    }

    final DateTime start = _day(sprint.startDate!.toLocal());
    final DateTime end = _day(sprint.endDate!.toLocal());
    final int days = (end.difference(start).inDays + 1).clamp(2, 120);

    // Points burned (completed) per day, then the remaining-points series.
    final List<double> burned = List<double>.filled(days, 0);
    for (final Task t in sprintTasks) {
      if (!t.done || t.points == 0) {
        continue;
      }
      final int idx = _day(
        t.updatedAt.toLocal(),
      ).difference(start).inDays.clamp(0, days - 1);
      burned[idx] += t.points;
    }
    final List<double> remaining = <double>[];
    double cum = 0;
    for (int d = 0; d < days; d++) {
      cum += burned[d];
      remaining.add((total - cum).clamp(0, total.toDouble()));
    }

    final List<double> ideal = <double>[
      for (int d = 0; d < days; d++) total * (1 - d / (days - 1)),
    ];

    final DateTime today = _day(DateTime.now());
    final int todayIdx = today.difference(start).inDays.clamp(0, days - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 200,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BurndownPainter(
              ideal: ideal,
              remaining: remaining,
              actualUpTo: today.isBefore(start) ? -1 : todayIdx,
              total: total.toDouble(),
              axis: scheme.outlineVariant,
              idealColor: scheme.onSurfaceVariant,
              actualColor: AppColors.brand,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              shortDate(start),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            _legend(scheme),
            Text(
              shortDate(end),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(ColorScheme scheme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _dot(AppColors.brand),
      const SizedBox(width: 4),
      const Text('Actual', style: TextStyle(fontSize: 11)),
      const SizedBox(width: 12),
      _dot(scheme.onSurfaceVariant),
      const SizedBox(width: 4),
      const Text('Ideal', style: TextStyle(fontSize: 11)),
    ],
  );

  Widget _dot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _hint(ColorScheme scheme, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _BurndownPainter extends CustomPainter {
  _BurndownPainter({
    required this.ideal,
    required this.remaining,
    required this.actualUpTo,
    required this.total,
    required this.axis,
    required this.idealColor,
    required this.actualColor,
  });

  final List<double> ideal;
  final List<double> remaining;
  final int actualUpTo;
  final double total;
  final Color axis;
  final Color idealColor;
  final Color actualColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 28, padBottom = 6, padTop = 6, padRight = 4;
    final double w = size.width - padLeft - padRight;
    final double h = size.height - padBottom - padTop;
    final int n = ideal.length;
    if (n < 2 || w <= 0 || h <= 0) {
      return;
    }

    double x(int i) => padLeft + w * (i / (n - 1));
    double y(double v) => padTop + h * (1 - (v / total).clamp(0, 1));

    final Paint axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1;
    // y axis + baseline
    canvas.drawLine(
      Offset(padLeft, padTop),
      Offset(padLeft, padTop + h),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padLeft, padTop + h),
      Offset(padLeft + w, padTop + h),
      axisPaint,
    );
    // y labels (0 and total)
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, double yy) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(color: axis, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, yy - tp.height / 2));
    }

    label(total.toInt().toString(), y(total));
    label('0', y(0));

    Path lineOf(List<double> data, int upTo) {
      final Path p = Path();
      for (int i = 0; i <= upTo; i++) {
        final Offset o = Offset(x(i), y(data[i]));
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      return p;
    }

    // ideal (dashed-ish: thin line)
    canvas.drawPath(
      lineOf(ideal, n - 1),
      Paint()
        ..color = idealColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    // actual up to today
    if (actualUpTo >= 0) {
      canvas.drawPath(
        lineOf(remaining, actualUpTo),
        Paint()
          ..color = actualColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_BurndownPainter old) =>
      old.remaining != remaining ||
      old.ideal != ideal ||
      old.actualUpTo != actualUpTo;
}
