import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/spacing.dart';
import 'motion.dart';

/// A circular progress indicator with a centred label — an alternative to a
/// linear progress bar. [value] is 0..1; it eases in on load unless reduced
/// motion is preferred.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 120,
    this.stroke = 12,
    this.label,
    this.caption,
    this.trackColor,
  });

  final double value;
  final Color color;
  final double size;
  final double stroke;
  final String? label;
  final String? caption;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double target = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target),
        duration: prefersReducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            color: color,
            stroke: stroke,
            track:
                trackColor ??
                scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.stroke,
    required this.track,
  });

  final double value;
  final Color color;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = color
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
