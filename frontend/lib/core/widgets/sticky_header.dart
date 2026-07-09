import 'package:flutter/material.dart';

/// One labelled group in a [StickySectionList].
class StickySection {
  const StickySection({required this.label, required this.children});
  final String label;
  final List<Widget> children;
}

/// A scrollable list of labelled [sections] whose headers pin to the top while
/// their rows scroll beneath them — the standard grouped-list wayfinding aid.
class StickySectionList extends StatelessWidget {
  const StickySectionList({
    super.key,
    required this.sections,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  final List<StickySection> sections;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: <Widget>[
              for (final StickySection section in sections) ...<Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(label: section.label),
                ),
                SliverList.list(children: section.children),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.label});
  final String label;

  static const double _height = 34;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}
