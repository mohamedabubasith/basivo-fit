import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// Staggered entrance: fade, rise and a gentle spring settle. Skipped with reduce-motion.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
  });
  final int index;
  final double offset;
  final Widget child;
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _delay = Timer(Motion.stagger * widget.index.clamp(0, 8), () {
      if (mounted) _c.forward();
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
    if (context.reduceMotion) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final fade = Curves.easeOut.transform((_c.value * 1.6).clamp(0, 1));
        final rise = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * widget.offset),
            child: Transform.scale(scale: 0.97 + 0.03 * rise, child: child),
          ),
        );
      },
    );
  }
}

/// Counts up from the previous value with an ease-out curve.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });
  final double value;
  final Duration duration;
  final Widget Function(BuildContext, double) builder;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (c, v, _) => builder(c, v),
    );
  }
}

/// Tap feedback that scales the child slightly without moving the layout around it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.borderRadius = Radii.card,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double borderRadius;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.975 : 1,
          duration: _down ? Motion.fast : const Duration(milliseconds: 260),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Loading placeholder with a moving shine.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 120});
  final double height;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + 3 * _c.value, 0),
                end: Alignment(-0.5 + 3 * _c.value, 0),
                colors: [c.card, c.card2, c.card],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
