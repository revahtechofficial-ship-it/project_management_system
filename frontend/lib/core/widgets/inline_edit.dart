import 'package:flutter/material.dart';

/// Click-to-edit text: renders [value] as a label (with a pencil affordance on
/// hover) that becomes a text field when tapped. Commits on Enter or focus
/// loss via [onSubmit]; Escape cancels. Keeps read views uncluttered while
/// allowing quick edits in place.
class InlineEditText extends StatefulWidget {
  const InlineEditText({
    super.key,
    required this.value,
    required this.onSubmit,
    this.style,
    this.hint = 'Untitled',
  });

  final String value;
  final Future<void> Function(String value) onSubmit;
  final TextStyle? style;
  final String hint;

  @override
  State<InlineEditText> createState() => _InlineEditTextState();
}

class _InlineEditTextState extends State<InlineEditText> {
  final FocusNode _focus = FocusNode();
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  bool _editing = false;
  bool _hover = false;
  bool _saving = false;

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _controller.text = widget.value;
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  Future<void> _commit() async {
    if (_saving) {
      return;
    }
    final String next = _controller.text.trim();
    if (next.isEmpty || next == widget.value) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(next);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        style: widget.style,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
      );
    }
    final String text = widget.value.isEmpty ? widget.hint : widget.value;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _start,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.value.isEmpty
                    ? (widget.style ?? const TextStyle()).copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      )
                    : widget.style,
              ),
            ),
            const SizedBox(width: 6),
            Opacity(
              opacity: _hover ? 1 : 0,
              child: Icon(
                Icons.edit_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
