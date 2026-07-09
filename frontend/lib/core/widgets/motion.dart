import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Whether motion should be suppressed (the "reduce motion" preference feeds
/// `MediaQuery.disableAnimations`, which also mirrors the OS setting).
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// Text that counts up to a numeric [text] on first build (and animates
/// between values on change). Non-numeric strings render unchanged. Any
/// prefix/suffix (currency, %, k, h …) is preserved around the animated digits.
class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 750),
  });

  final String text;
  final TextStyle? style;
  final Duration duration;

  static final RegExp _number = RegExp(r'^(\D*?)(-?\d[\d,]*\.?\d*)(.*)$');

  @override
  Widget build(BuildContext context) {
    final RegExpMatch? m = _number.firstMatch(text);
    if (m == null || prefersReducedMotion(context)) {
      return Text(text, style: style);
    }
    final String prefix = m.group(1) ?? '';
    final String rawNumber = m.group(2) ?? '';
    final String suffix = m.group(3) ?? '';
    final bool commas = rawNumber.contains(',');
    final String clean = rawNumber.replaceAll(',', '');
    final double? value = double.tryParse(clean);
    if (value == null) {
      return Text(text, style: style);
    }
    final int decimals = clean.contains('.') ? clean.split('.')[1].length : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, _) =>
          Text('$prefix${_format(v, decimals, commas)}$suffix', style: style),
    );
  }

  static String _format(double v, int decimals, bool commas) {
    final String s = v.toStringAsFixed(decimals);
    if (!commas) {
      return s;
    }
    final List<String> parts = s.split('.');
    parts[0] = _group(parts[0]);
    return parts.join('.');
  }

  static String _group(String intStr) {
    final bool neg = intStr.startsWith('-');
    final String digits = neg ? intStr.substring(1) : intStr;
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(digits[i]);
    }
    return '${neg ? '-' : ''}$buf';
  }
}

/// Raises and gently scales its [child] while the pointer hovers — a subtle
/// SaaS "lift". A no-op when reduced motion is preferred.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.scale = 1.02,
  });

  final Widget child;
  final double borderRadius;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return widget.child;
    }
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _hover
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades and slides its [child] up into place on first appearance, optionally
/// staggered by [index]. Renders immediately when reduced motion is preferred.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 340),
    this.offset = 12,
  });

  final Widget child;
  final int index;
  final Duration stagger;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (prefersReducedMotion(context)) {
      _c.value = 1;
      return;
    }
    _delay = Timer(widget.stagger * widget.index, () {
      if (mounted) {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, (1 - _fade.value) * widget.offset),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Fires a brief central check-burst (a popping badge, an expanding ring and
/// a spray of particles) to celebrate a completion. No-op under reduced motion.
void celebrate(BuildContext context) {
  if (prefersReducedMotion(context)) {
    return;
  }
  final OverlayState overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) =>
        _CompletionBurst(onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _CompletionBurst extends StatefulWidget {
  const _CompletionBurst({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_CompletionBurst> createState() => _CompletionBurstState();
}

class _CompletionBurstState extends State<_CompletionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  static const List<Color> _colors = <Color>[
    AppColors.brand,
    AppColors.green,
    AppColors.amber,
    AppColors.violet,
    AppColors.rose,
    AppColors.sky,
  ];

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) {
            final double t = _c.value;
            // Badge pops in, then everything fades out over the back third.
            final double pop = Curves.elasticOut.transform(
              (t / 0.5).clamp(0.0, 1.0),
            );
            final double fade = t < 0.7
                ? 1.0
                : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
            final double ring = Curves.easeOut.transform(t);
            return Opacity(
              opacity: fade,
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Expanding ring.
                    Container(
                      width: 60 + ring * 150,
                      height: 60 + ring * 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.green.withValues(
                            alpha: (1 - ring) * 0.6,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                    // Particle spray.
                    for (int i = 0; i < 12; i++)
                      _particle(i, Curves.easeOut.transform(t)),
                    // Check badge.
                    Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFF22C55E),
                              Color(0xFF16A34A),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _particle(int i, double t) {
    final double angle = (i / 12) * 2 * math.pi;
    final double distance = t * 96;
    final double dx = math.cos(angle) * distance;
    final double dy = math.sin(angle) * distance;
    final Color color = _colors[i % _colors.length];
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
