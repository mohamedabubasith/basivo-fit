import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/tokens.dart';

/// Switches theme with a circle that grows from the tapped button: the old look is
/// captured as a picture and a hole in it widens to show the new theme underneath.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});
  final Widget child;
  static ThemeRevealState? of(BuildContext context) =>
      context.findAncestorStateOfType<ThemeRevealState>();
  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  ui.Image? _old;
  Offset _origin = Offset.zero;

  Future<void> run(Offset origin, VoidCallback change) async {
    if (_c.isAnimating || MediaQuery.of(context).disableAnimations) {
      change();
      return;
    }
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );
      setState(() {
        _old = img;
        _origin = origin;
      });
      change();
      await _c.forward(from: 0);
    } catch (_) {
      change();
    } finally {
      final img = _old;
      if (mounted) setState(() => _old = null);
      img?.dispose();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    children: [
      RepaintBoundary(key: _key, child: widget.child),
      if (_old != null)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(
                painter: _HolePainter(
                  _old!,
                  _origin,
                  Motion.ease.transform(_c.value),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _HolePainter extends CustomPainter {
  _HolePainter(this.image, this.origin, this.t);
  final ui.Image image;
  final Offset origin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.sqrt(
      math.pow(math.max(origin.dx, size.width - origin.dx), 2) +
          math.pow(math.max(origin.dy, size.height - origin.dy), 2),
    );
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: origin, radius: r * t));
    canvas.clipPath(clip);
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.t != t || old.image != image;
}
