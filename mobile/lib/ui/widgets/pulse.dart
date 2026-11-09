import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// A heart that beats at the real heart rate (lub-dub pattern).
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({super.key, required this.bpm, this.size = 40});
  final int bpm;
  final double size;
  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _period,
  );
  Duration get _period => Duration(
    milliseconds: (60000 / (widget.bpm > 0 ? widget.bpm : 60)).round().clamp(
      300,
      2000,
    ),
  );
  static final _beat = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.22,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 15,
    ),
    TweenSequenceItem(tween: Tween<double>(begin: 1.22, end: 0.96), weight: 15),
    TweenSequenceItem(tween: Tween<double>(begin: 0.96, end: 1.12), weight: 15),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.12,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 15,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 40),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(BeatingHeart old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _c.duration = _period;
      if (!context.reduceMotion) _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ScaleTransition(
          scale: _beat.animate(_c),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: c.heartBg,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: widget.size,
              color: c.heart,
            ),
          ),
        ),
      ),
    );
  }
}

/// A heartbeat trace that runs across the card at the current rate.
class EcgLine extends StatefulWidget {
  const EcgLine({super.key, required this.bpm, this.height = 44});
  final int bpm;
  final double height;
  @override
  State<EcgLine> createState() => _EcgLineState();
}

class _EcgLineState extends State<EcgLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _period,
  );
  Duration get _period => Duration(
    milliseconds: (120000 / (widget.bpm > 0 ? widget.bpm : 60)).round().clamp(
      700,
      4000,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.value = 0.6;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(EcgLine old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm && !context.reduceMotion) {
      _c.duration = _period;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(painter: _EcgPainter(_c, context.c.heart)),
      ),
    ),
  );
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const beat = [
      [14.0, 0.0],
      [4.0, -6.0],
      [4.0, 6.0],
      [6.0, 0.0],
      [3.0, 6.0],
      [5.0, -34.0],
      [5.0, 40.0],
      [4.0, -12.0],
      [5.0, 0.0],
      [8.0, -5.0],
      [8.0, 5.0],
      [16.0, 0.0],
    ];
    final sx = size.width / 320, sy = size.height / 60;
    final path = Path()..moveTo(0, 30 * sy);
    var x = 0.0, y = 30.0;
    for (var i = 0; i < 4; i++) {
      for (final s in beat) {
        x += s[0];
        y += s[1];
        path.lineTo(x * sx, y * sy);
      }
    }
    path.lineTo(size.width, 30 * sy);
    final metric = path.computeMetrics().first;
    final len = metric.length, seg = len * 0.52;
    final head = (t.value * (len + seg));
    final from = (head - seg).clamp(0.0, len), to = head.clamp(0.0, len);
    if (to <= from) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        metric.getTangentForOffset(from)!.position,
        metric.getTangentForOffset(to)!.position,
        [color.withValues(alpha: 0), color],
      );
    canvas.drawPath(metric.extractPath(from, to), p);
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.color != color;
}

/// The Basivo Fit mark: a volt (lime to teal) tile with a bold lowercase "b"
/// whose bowl carries a heartbeat. Matches assets/brand/logo.svg and the app icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 512);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Radius.circular(116),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(512, 512),
          const [Color(0xFFDDFB62), Color(0xFF2FD9B9)],
        ),
    );
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF07080C)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(
      const Offset(164, 112),
      const Offset(164, 312),
      ink..strokeWidth = 52,
    );
    canvas.drawCircle(const Offset(262, 312), 98, ink);
    canvas.drawPath(
      Path()
        ..moveTo(196, 312)
        ..lineTo(222, 312)
        ..lineTo(240, 276)
        ..lineTo(266, 352)
        ..lineTo(286, 300)
        ..lineTo(298, 312)
        ..lineTo(328, 312),
      ink..strokeWidth = 22,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
