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
        _BurndownChart(
          ideal: ideal,
          remaining: remaining,
          actualUpTo: today.isBefore(start) ? -1 : todayIdx,
          total: total.toDouble(),
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

/// The burndown plot with a hover marker + tooltip.
class _BurndownChart extends StatefulWidget {
  const _BurndownChart({
    required this.ideal,
    required this.remaining,
    required this.actualUpTo,
    required this.total,
  });

  final List<double> ideal;
  final List<double> remaining;
  final int actualUpTo;
  final double total;

  @override
  State<_BurndownChart> createState() => _BurndownChartState();
}

class _BurndownChartState extends State<_BurndownChart> {
  static const double _padLeft = 28;
  static const double _padRight = 4;
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int n = widget.ideal.length;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        void update(Offset local) {
          final double w = c.maxWidth - _padLeft - _padRight;
          if (n < 2 || w <= 0) {
            return;
          }
          final double rel = ((local.dx - _padLeft) / w).clamp(0.0, 1.0);
          final int idx = (rel * (n - 1)).round();
          if (idx != _hover) {
            setState(() => _hover = idx);
          }
        }

        return Semantics(
          label: 'Sprint burndown: remaining story points versus the ideal '
              'trend',
          child: MouseRegion(
          onHover: (e) => update(e.localPosition),
          onExit: (_) => setState(() => _hover = null),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BurndownPainter(
                ideal: widget.ideal,
                remaining: widget.remaining,
                actualUpTo: widget.actualUpTo,
                total: widget.total,
                axis: scheme.outlineVariant,
                idealColor: scheme.onSurfaceVariant,
                actualColor: AppColors.brand,
                hoverIndex: _hover,
                tooltipBg: scheme.inverseSurface,
                tooltipFg: scheme.onInverseSurface,
              ),
            ),
          ),
          ),
        );
      },
    );
  }
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
    this.hoverIndex,
    required this.tooltipBg,
    required this.tooltipFg,
  });

  final List<double> ideal;
  final List<double> remaining;
  final int actualUpTo;
  final double total;
  final Color axis;
  final Color idealColor;
  final Color actualColor;
  final int? hoverIndex;
  final Color tooltipBg;
  final Color tooltipFg;

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

    // Hover guide, markers and a value tooltip.
    final int? hi = hoverIndex;
    if (hi != null && hi >= 0 && hi < n) {
      final double gx = x(hi);
      canvas.drawLine(
        Offset(gx, padTop),
        Offset(gx, padTop + h),
        Paint()
          ..color = axis
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(gx, y(ideal[hi])), 3, Paint()..color = idealColor);
      final bool hasActual = hi <= actualUpTo;
      if (hasActual) {
        canvas.drawCircle(
          Offset(gx, y(remaining[hi])),
          3.5,
          Paint()..color = actualColor,
        );
      }

      final String text = hasActual
          ? 'Rem ${remaining[hi].toInt()} · Ideal ${ideal[hi].toInt()}'
          : 'Ideal ${ideal[hi].toInt()}';
      final TextPainter tip = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: tooltipFg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      const double padX = 6, padY = 4;
      double bx = gx - (tip.width + padX * 2) / 2;
      bx = bx.clamp(padLeft, size.width - padRight - tip.width - padX * 2);
      final Rect box = Rect.fromLTWH(
        bx,
        padTop,
        tip.width + padX * 2,
        tip.height + padY * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..color = tooltipBg,
      );
      tip.paint(canvas, Offset(bx + padX, padTop + padY));
    }
  }

  @override
  bool shouldRepaint(_BurndownPainter old) =>
      old.remaining != remaining ||
      old.ideal != ideal ||
      old.actualUpTo != actualUpTo ||
      old.hoverIndex != hoverIndex;
}
