import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/spacing.dart';
import 'glass.dart';
import 'motion.dart';
import 'sparkline.dart';

/// A KPI tile: a gradient icon badge, a large value, a label, and either a
/// trend pill, a footer caption, or a progress bar — on a frosted-glass
/// surface. Tappable when [onTap] is given (AGENTS.md §1 `core/widgets`).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.footer,
    this.progress,
    this.trend,
    this.trendPositive = true,
    this.onTap,
    this.spark,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? footer;
  final double? progress;

  /// An optional tiny trend series rendered as a sparkline at the card foot.
  final List<double>? spark;

  /// A short delta caption (e.g. "+3 this week"). Rendered as a colored pill
  /// and takes precedence over [footer].
  final String? trend;
  final bool trendPositive;

  /// When set, the whole card becomes tappable (e.g. to open a filtered list).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget card = GlassSurface(
      borderRadius: 18,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.shade(color),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: color.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedNumberText(value,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: tabularFigures)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                if (progress != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: progress!.clamp(0.0, 1.0),
                      ),
                      duration: prefersReducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext context, double v, _) =>
                          LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        color: color,
                      ),
                    ),
                  ),
                ] else if (trend != null) ...<Widget>[
                  const SizedBox(height: 10),
                  _TrendPill(text: trend!, positive: trendPositive),
                ] else if (footer != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(footer!,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
                if (spark != null && spark!.length >= 2) ...<Widget>[
                  const SizedBox(height: 12),
                  Sparkline(values: spark!, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return onTap != null
        ? HoverLift(borderRadius: 18, child: card)
        : card;
  }
}

/// A small up/down delta chip used inside [StatCard].
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.text, required this.positive});
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final Color tone = positive ? AppColors.green : AppColors.rose;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            positive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: tone,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out [StatCard]s (or any cards) in a responsive grid that collapses
/// from four columns to two to one as width shrinks.
class StatCardGrid extends StatelessWidget {
  const StatCardGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final int cols = w >= 1080 ? 4 : (w >= 720 ? 2 : 1);
        const double gap = 16;
        final double cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final (int i, Widget card) in cards.indexed)
              SizedBox(
                width: cardW,
                child: FadeSlideIn(index: i, child: card),
              ),
          ],
        );
      },
    );
  }
}
