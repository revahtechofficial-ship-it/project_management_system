import 'package:flutter/material.dart';

import 'glass.dart';

/// A shimmering placeholder block shown while real content loads. Compose
/// several to mirror a card's layout so the UI never flashes blank (or a
/// transient error) before data arrives (AGENTS.md §1 `core/widgets`).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color base = scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final Color highlight = scheme.surfaceContainerHighest.withValues(
      alpha: 0.95,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double dx = -1.0 + 3.0 * _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: <Color>[base, highlight, base],
              stops: const <double>[0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// A stack of full-width [Skeleton] lines, for list/paragraph placeholders.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 3, this.spacing = 12});

  final int lines;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < lines; i++) ...<Widget>[
          if (i > 0) SizedBox(height: spacing),
          const Skeleton(width: double.infinity, height: 14),
        ],
      ],
    );
  }
}

/// A column of shimmering row placeholders for list-style pages (Tasks, Pages).
/// Uses [MainAxisSize.min] so it's safe inside both `Expanded` and scroll views.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < rows; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 10),
          const _SkeletonRow(),
        ],
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Skeleton(width: 38, height: 38, radius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Skeleton(width: double.infinity, height: 13),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 11),
              ],
            ),
          ),
          SizedBox(width: 12),
          Skeleton(width: 54, height: 22, radius: 11),
        ],
      ),
    );
  }
}

/// A responsive grid of shimmering card placeholders for tile/grid pages
/// (Projects, Team).
class SkeletonTiles extends StatelessWidget {
  const SkeletonTiles({super.key, this.count = 6, this.minTileWidth = 280});

  final int count;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = (c.maxWidth / minTileWidth).floor().clamp(1, 4);
        const double gap = 16;
        final double tileW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              SizedBox(width: tileW, child: const _SkeletonCard()),
          ],
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const GlassSurface(
      borderRadius: 18,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Skeleton(width: 40, height: 40, radius: 10),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 14)),
              ],
            ),
            SizedBox(height: 18),
            Skeleton(width: double.infinity, height: 11),
            SizedBox(height: 10),
            Skeleton(width: 140, height: 11),
          ],
        ),
      ),
    );
  }
}
