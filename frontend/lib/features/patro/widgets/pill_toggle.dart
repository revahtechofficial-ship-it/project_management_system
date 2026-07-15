import 'package:flutter/material.dart';

/// A two-option pill switch.
///
/// Hand-rolled rather than a [SegmentedButton]: that widget sizes every
/// segment to one shared intrinsic width, and on the web it mismeasures a
/// Devanagari label whose fallback font has not loaded yet — leaving too
/// little room for the other segment, which then wraps mid-word.
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  /// The labels, in index order. Usually two, but any number works.
  final List<String> labels;

  /// Index of the selected label.
  final int selected;

  final ValueChanged<int> onChanged;

  /// When true the chips share the full available width equally, so the toggle
  /// stretches to its parent instead of sizing to its labels. Use it where the
  /// labels together might be wider than a narrow card — three of them on a
  /// phone — so it fills the row rather than spilling past it.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            if (expand)
              Expanded(
                child: _Chip(
                  label: labels[i],
                  selected: i == selected,
                  onTap: () => onChanged(i),
                ),
              )
            else
              _Chip(
                label: labels[i],
                selected: i == selected,
                onTap: () => onChanged(i),
              ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            label,
            softWrap: false,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
