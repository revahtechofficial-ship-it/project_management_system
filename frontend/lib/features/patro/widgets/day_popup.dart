import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/patro_providers.dart';
import 'day_card.dart';

/// Opens the day card at [at], a global position — the point that was clicked.
///
/// A click, not a hover. Hovering a cell only lights it up; the card is a thing
/// you ask for. That is the right way round: a card that appears wherever the
/// pointer happens to rest follows you across the month like a fly, and reading
/// a grid means moving the pointer across a great many days you did not mean to
/// ask about.
///
/// Being click-driven, it stays until dismissed, which is what makes its
/// buttons genuinely reachable — there is no seam to cross and no race to lose.
/// It closes on a click anywhere else, on Escape, or on pressing one of its own
/// buttons.
void showDayPopup(
  BuildContext context, {
  required Offset at,
  required DateTime date,
  required bool nepali,
  required List<CalendarEvent> events,
  required VoidCallback onViewDetails,
  required VoidCallback onAddNote,
  required VoidCallback onSetReminder,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  late final OverlayEntry entry;
  void close() {
    if (entry.mounted) {
      entry.remove();
    }
  }

  /// Every button closes the card and then acts — none of them wants it left
  /// hanging over the thing it just opened.
  VoidCallback thenClose(VoidCallback action) => () {
    close();
    action();
  };

  entry = OverlayEntry(
    builder: (BuildContext overlayContext) {
      final Size screen = MediaQuery.sizeOf(overlayContext);
      const double gap = 12;
      const double cardHeight = 300;

      // Below-right of the click by default; flipped when that would run off
      // the edge, because a card half off the screen is worse than one behind
      // the hand.
      double left = at.dx + gap;
      if (left + DayCard.width > screen.width - 8) {
        left = at.dx - DayCard.width - gap;
      }
      left = left.clamp(8.0, screen.width - DayCard.width - 8);

      double top = at.dy + gap;
      if (top + cardHeight > screen.height - 8) {
        top = at.dy - cardHeight - gap;
      }
      top = top.clamp(8.0, screen.height - 80);

      return Stack(
        children: <Widget>[
          // An invisible sheet over everything, so a click anywhere else
          // dismisses. Without it the card would outlive its usefulness and
          // have to be clicked shut, which nobody does.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: _EscapeToClose(
              onEscape: close,
              child: _FadeScaleIn(
                child: DayCard(
                  date: date,
                  nepali: nepali,
                  events: events,
                  onViewDetails: thenClose(onViewDetails),
                  onAddNote: thenClose(onAddNote),
                  onSetReminder: thenClose(onSetReminder),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
}

/// Escape closes it. A popup you can only dismiss with the mouse is a popup
/// that gets in the way of the keyboard.
class _EscapeToClose extends StatefulWidget {
  const _EscapeToClose({required this.onEscape, required this.child});

  final VoidCallback onEscape;
  final Widget child;

  @override
  State<_EscapeToClose> createState() => _EscapeToCloseState();
}

class _EscapeToCloseState extends State<_EscapeToClose> {
  final FocusNode _node = FocusNode(debugLabel: 'day card');

  @override
  void initState() {
    super.initState();
    // Taken, not requested politely: the click that opened this card left the
    // focus on the cell, and `autofocus` defers to a scope that already has a
    // focused child. So it would do nothing here, and Escape would go unheard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _node.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: (FocusNode _, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onEscape();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

/// Fades and scales the card in. No matching exit: it is removed outright, so
/// dismissing feels instant rather than sticky.
class _FadeScaleIn extends StatefulWidget {
  const _FadeScaleIn({required this.child});

  final Widget child;

  @override
  State<_FadeScaleIn> createState() => _FadeScaleInState();
}

class _FadeScaleInState extends State<_FadeScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 130),
    vsync: this,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  // From 96%, not from nothing: a card that grows out of a point draws the eye
  // to the growing rather than to the words.
  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topLeft,
        child: widget.child,
      ),
    );
  }
}
