import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../providers/patro_providers.dart';
import 'day_hover_card.dart';

/// Wraps a day cell so that pointing at it raises the hover card.
///
/// Two of the requirements pull against each other, and it is worth being
/// explicit about how they are reconciled.
///
///   * The card must vanish the moment the pointer leaves.
///   * The card carries buttons the reader is meant to click.
///
/// Taken literally, the first makes the second impossible: leaving the cell to
/// reach a button would destroy the button on the way. So the card lives as
/// long as the pointer is over *either* the cell or the card, and dies the
/// instant it is over neither. Crossing the seam between the two fires
/// onExit(cell) and onEnter(card) as separate events, so the removal is
/// deferred by a single frame and cancelled if the card catches the pointer.
/// One frame is 16ms — it reads as immediate, and it is what makes the buttons
/// reachable at all.
///
/// There is no delay before the card appears. A tooltip that makes you wait is
/// a tooltip you stop using.
class DayHoverRegion extends StatefulWidget {
  const DayHoverRegion({
    super.key,
    required this.date,
    required this.nepali,
    required this.events,
    required this.onViewDetails,
    required this.onAddNote,
    required this.onSetReminder,
    required this.child,
  });

  final DateTime date;
  final bool nepali;
  final List<CalendarEvent> events;

  final VoidCallback onViewDetails;
  final VoidCallback onAddNote;
  final VoidCallback onSetReminder;

  final Widget child;

  @override
  State<DayHoverRegion> createState() => _DayHoverRegionState();
}

class _DayHoverRegionState extends State<DayHoverRegion> {
  OverlayEntry? _entry;
  bool _pointerInCell = false;
  bool _pointerInCard = false;

  /// Where the card sits. Recomputed as the pointer moves, so it tracks the
  /// cursor rather than pinning to the cell.
  Offset _at = Offset.zero;

  @override
  void dispose() {
    // The overlay outlives this widget's element, so it has to be taken down by
    // hand — otherwise a card left behind by a scroll keeps floating.
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _show(Offset globalPosition) {
    _at = globalPosition;
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(builder: _buildCard);
    overlay.insert(_entry!);
  }

  void _hideIfLeft() {
    // A frame's grace: leaving the cell for the card fires exit-then-enter, and
    // without this the card would be gone before the enter arrived.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pointerInCell || _pointerInCard) {
        return;
      }
      _entry?.remove();
      _entry = null;
    });
  }

  /// Closes the card and then does something — every button wants both.
  void _dismissThen(VoidCallback action) {
    _pointerInCell = false;
    _pointerInCard = false;
    _entry?.remove();
    _entry = null;
    action();
  }

  Widget _buildCard(BuildContext overlayContext) {
    final Size screen = MediaQuery.sizeOf(overlayContext);
    const double gap = 14;
    const double cardHeight = 300;

    // Prefer down and to the right of the cursor. Flip when that would run off
    // the edge — a card half off the screen is worse than one behind the hand.
    double left = _at.dx + gap;
    if (left + DayHoverCard.width > screen.width - 8) {
      left = _at.dx - DayHoverCard.width - gap;
    }
    left = left.clamp(8.0, screen.width - DayHoverCard.width - 8);

    double top = _at.dy + gap;
    if (top + cardHeight > screen.height - 8) {
      top = _at.dy - cardHeight - gap;
    }
    top = top.clamp(8.0, screen.height - 60);

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        onEnter: (_) => _pointerInCard = true,
        onExit: (_) {
          _pointerInCard = false;
          _hideIfLeft();
        },
        child: _FadeScaleIn(
          child: DayHoverCard(
            date: widget.date,
            nepali: widget.nepali,
            events: widget.events,
            onViewDetails: () => _dismissThen(widget.onViewDetails),
            onAddNote: () => _dismissThen(widget.onAddNote),
            onSetReminder: () => _dismissThen(widget.onSetReminder),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (PointerEnterEvent e) {
        _pointerInCell = true;
        _show(e.position);
      },
      onHover: (PointerHoverEvent e) {
        if (_pointerInCell) {
          _show(e.position);
        }
      },
      onExit: (_) {
        _pointerInCell = false;
        _hideIfLeft();
      },
      child: widget.child,
    );
  }
}

/// Fades and scales the card in. There is no matching exit: the card is removed
/// outright when the pointer leaves, which is what "disappear immediately"
/// asks for and what makes the calendar feel responsive rather than sticky.
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
