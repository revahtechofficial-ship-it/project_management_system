import 'package:flutter/material.dart';

import '../utils/feedback.dart';

/// A small icon button that copies [text] to the clipboard and confirms with a
/// toast. Use next to IDs, links and codes.
class CopyButton extends StatelessWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.tooltip = 'Copy',
    this.label = 'Copied to clipboard',
    this.icon = Icons.copy_rounded,
    this.size = 18,
  });

  final String text;
  final String tooltip;
  final String label;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      onPressed: () => context.copyToClipboard(text, label: label),
    );
  }
}
