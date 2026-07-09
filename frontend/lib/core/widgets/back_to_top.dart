import 'package:flutter/material.dart';

import 'motion.dart';

/// Wraps a scrollable built via [builder], showing a "back to top" button once
/// the user scrolls past [threshold]. The builder must attach the supplied
/// [ScrollController] to its scroll view.
class BackToTop extends StatefulWidget {
  const BackToTop({super.key, required this.builder, this.threshold = 400});

  final Widget Function(ScrollController controller) builder;
  final double threshold;

  @override
  State<BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<BackToTop> {
  final ScrollController _controller = ScrollController();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final bool show =
        _controller.hasClients && _controller.offset > widget.threshold;
    if (show != _visible) {
      setState(() => _visible = show);
    }
  }

  void _toTop() {
    if (!_controller.hasClients) {
      return;
    }
    if (prefersReducedMotion(context)) {
      _controller.jumpTo(0);
    } else {
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.builder(_controller),
        Positioned(
          right: 8,
          bottom: 8,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 1.6),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Back to top',
                onPressed: _visible ? _toTop : null,
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
