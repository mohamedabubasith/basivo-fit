import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Animates a 0→1 progress once when shown (instant with reduce-motion).
class DrawIn extends StatelessWidget {
  const DrawIn({
    super.key,
    required this.builder,
    this.duration = Motion.draw,
    this.delay = 0.0,
    this.curve = Motion.ease,
  });
  final Widget Function(BuildContext, double) builder;
  final Duration duration;
  final double delay;
  final Curve curve;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return builder(context, 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (c, t, _) =>
          builder(c, curve.transform(((t - delay) / (1 - delay)).clamp(0, 1))),
    );
  }
}

TextPainter _text(String s, TextStyle style) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
)..layout();

void _dashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint p, {
  double dash = 1.5,
  double gap = 6,
}) {
  final d = (b - a).distance, dir = (b - a) / d;
  for (var x = 0.0; x < d; x += dash + gap) {
    canvas.drawLine(a + dir * x, a + dir * math.min(x + dash, d), p);
  }
}

// ---------- Sparkline ----------
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 32,
  });
  final List<double> data;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: DrawIn(
        builder: (_, t) => CustomPaint(painter: _SparkPainter(data, color, t)),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color, this.t);
  final List<double> data;
  final Color color;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final lo = data.reduce(math.min), hi = data.reduce(math.max);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = hi == lo
          ? size.height / 2
          : size.height - (data[i] - lo) / (hi - lo) * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter o) =>
      o.t != t || o.color != color || o.data != data;
}

// ---------- Ring ----------
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.value,
    required this.max,
    required this.child,
    this.size = 140,
    this.stroke = 13,
    this.color,
  });
  final double value, max, size, stroke;
  final Color? color;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final target = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (context.reduceMotion)
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                target,
                c.track,
                color ?? c.secondary,
                stroke,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeOutCubic,
              builder: (_, p, _) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(p, c.track, color ?? c.secondary, stroke),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.track, this.color, this.stroke);
  final double p, stroke;
  final Color track, color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    if (p <= 0) return;
    base.shader = ui.Gradient.sweep(
      r.center,
      [color.withValues(alpha: 0.75), color],
      [0, 1],
      TileMode.clamp,
      -math.pi / 2,
      -math.pi / 2 + math.pi * 2 * p,
    );
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * p, false, base);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.p != p || o.color != color || o.track != track;
}

// ---------- Bars ----------
class Bars extends StatelessWidget {
  const Bars({
    super.key,
    required this.data,
    required this.labels,
    this.goal,
    this.format,
    this.height = 150,
    this.semanticsLabel,
  });
  final List<double> data;
  final List<String> labels;
  final double? goal;
  final String Function(double)? format;
  final double height;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = format ?? (v) => num0(v);
    final label =
        semanticsLabel ??
        [
          for (var i = 0; i < data.length; i++) '${labels[i]} ${fmt(data[i])}',
        ].join(', ');
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + 22,
          width: double.infinity,
          child: DrawIn(
            duration: Duration(milliseconds: 700 + data.length * 40),
            curve: Curves.linear,
            builder: (ctx, t) => CustomPaint(
              painter: _BarsPainter(data, labels, goal, fmt, t, c, height),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(
    this.data,
    this.labels,
    this.goal,
    this.fmt,
    this.t,
    this.c,
    this.h,
  );
  final List<double> data;
  final List<String> labels;
  final double? goal;
  final String Function(double) fmt;
  final double t, h;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final max = [...data, goal ?? 0].reduce(math.max) * 1.1;
    if (max <= 0) return;
    const gap = 8.0;
    final colW = (size.width - gap * (data.length - 1)) / data.length;
    final barW = math.min(colW, 32.0);
    for (var i = 0; i < data.length; i++) {
      // Each bar springs up a little after the previous one.
      final local = ((t * (data.length + 6) - i) / 7).clamp(0.0, 1.0);
      final grow = Curves.easeOutBack.transform(local);
      final bh = (data[i] / max * h) * grow;
      final cx = i * (colW + gap) + colW / 2;
      final hit = goal != null && data[i] >= goal!;
      final last = i == data.length - 1;
      final color = (hit ? c.up : c.secondary).withValues(
        alpha: last ? 1 : (hit ? 0.85 : 0.5),
      );
      if (bh > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, h - bh, barW, bh),
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: const Radius.circular(4),
            bottomRight: const Radius.circular(4),
          ),
          Paint()..color = color,
        );
      }
      if (labels[i].isNotEmpty) {
        final tp = _text(
          labels[i],
          TextStyle(color: c.mutedFg, fontSize: 12, fontFamily: kSans),
        );
        tp.paint(
          canvas,
          Offset((cx - tp.width / 2).clamp(0, size.width - tp.width), h + 6),
        );
      }
    }
    if (goal != null) {
      final y = h - goal! / max * h;
      _dashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = c.mutedFg
          ..strokeWidth = 1.5,
        dash: 5,
        gap: 4,
      );
      final tp = _text(
        'Goal ${fmt(goal!)}',
        TextStyle(color: c.mutedFg, fontSize: 11, fontFamily: kMono),
      );
      final r = Rect.fromLTWH(
        size.width - tp.width - 8,
        y - tp.height - 5,
        tp.width + 8,
        tp.height + 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()..color = c.card,
      );
      tp.paint(canvas, Offset(r.left + 4, r.top + 1));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.t != t || o.c != c || o.data != data;
}

// ---------- Hourly heart band ----------
class RangeChart extends StatelessWidget {
  const RangeChart({super.key, required this.points, this.height = 150});
  final List<HeartHour> points;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (points.length < 2) return const Text('Not enough readings yet today.');
    final peak = points.reduce((a, b) => b.max > a.max ? b : a);
    return Semantics(
      label:
          'Heart rate today from ${hourLabel(points.first.at)} to ${hourLabel(points.last.at)}. Highest ${peak.max} bpm around ${hourLabel(peak.at)}.',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: DrawIn(
                builder: (_, t) =>
                    CustomPaint(painter: _RangePainter(points, c.heart, t)),
              ),
            ),
            const SizedBox(height: Space.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final p in [
                  points.first,
                  points[points.length ~/ 2],
                  points.last,
                ])
                  Text(
                    hourLabel(p.at),
                    style: TextStyle(color: c.mutedFg, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter(this.pts, this.color, this.t);
  final List<HeartHour> pts;
  final Color color;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final lo = pts.map((p) => p.min).reduce(math.min) - 5.0,
        hi = pts.map((p) => p.max).reduce(math.max) + 5.0;
    double x(int i) => i / (pts.length - 1) * size.width;
    double y(num v) => size.height - (v - lo) / (hi - lo) * size.height;
    final band = Path()..moveTo(x(0), y(pts[0].max));
    for (var i = 1; i < pts.length; i++) {
      band.lineTo(x(i), y(pts[i].max));
    }
    for (var i = pts.length - 1; i >= 0; i--) {
      band.lineTo(x(i), y(pts[i].min));
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          color.withValues(alpha: 0.35 * t),
          color.withValues(alpha: 0.08 * t),
        ]),
    );
    final line = Path()..moveTo(x(0), y(pts[0].avg));
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(x(i), y(pts[i].avg));
    }
    final m = line.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    if (t >= 1) {
      canvas.drawCircle(
        Offset(x(pts.length - 1), y(pts.last.avg)),
        4.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RangePainter o) => o.t != t || o.color != color;
}

// ---------- Heart zones (day + week) ----------
Color zoneColor(AppColors c, Zone z) => switch (z) {
  Zone.light => c.zLight,
  Zone.moderate => c.zModerate,
  Zone.vigorous => c.zVigorous,
  Zone.peak => c.zPeak,
};

const _padR = 36.0;

({double lo, double hi}) _scale(ZoneLimits l, num max) =>
    (lo: 30, hi: math.max(l.peak + 16, max + 10).toDouble());

void _zoneLines(
  Canvas canvas,
  Size size,
  ZoneLimits l,
  double Function(num) y,
  AppColors c,
) {
  for (final (v, z) in [
    (l.peak, Zone.peak),
    (l.vigorous, Zone.vigorous),
    (l.moderate, Zone.moderate),
  ]) {
    _dashedLine(
      canvas,
      Offset(0, y(v)),
      Offset(size.width - _padR - 4, y(v)),
      Paint()
        ..color = zoneColor(c, z)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final tp = _text(
      '$v',
      TextStyle(color: c.mutedFg, fontSize: 11, fontFamily: kMono),
    );
    tp.paint(canvas, Offset(size.width - tp.width, y(v) - tp.height / 2));
  }
  final tp = _text(
    '30',
    TextStyle(color: c.mutedFg, fontSize: 11, fontFamily: kMono),
  );
  tp.paint(canvas, Offset(size.width - tp.width, size.height - tp.height));
}

/// Full-day heart rate in 5-minute steps. The line takes each zone's colour, and
/// touching or dragging shows the reading at that moment.
class HeartDayChart extends StatefulWidget {
  const HeartDayChart({super.key, required this.day, this.height = 230});
  final HeartDay day;
  final double height;
  @override
  State<HeartDayChart> createState() => _HeartDayChartState();
}

class _HeartDayChartState extends State<HeartDayChart> {
  int? _scrub;

  void _pick(Offset local, double width) {
    final d = widget.day;
    if (d.points.isEmpty) return;
    final plotW = width - _padR;
    final t =
        d.start.millisecondsSinceEpoch +
        (local.dx / plotW).clamp(0.0, 1.0) *
            d.end.difference(d.start).inMilliseconds;
    var best = 0;
    for (var i = 1; i < d.points.length; i++) {
      if ((d.points[i].t.millisecondsSinceEpoch - t).abs() <
          (d.points[best].t.millisecondsSinceEpoch - t).abs()) {
        best = i;
      }
    }
    if (best != _scrub) setState(() => _scrub = best);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c, d = widget.day;
    final sp = _scrub == null ? null : d.points[_scrub!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 22,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: Text(
              sp == null
                  ? 'Touch the chart to see each reading'
                  : '${clock(sp.t)} · ${sp.avg.round()} bpm (${sp.min.round()} to ${sp.max.round()})',
              key: ValueKey(sp?.t ?? 0),
              style: mono(
                context,
                size: 13,
                color: sp == null ? c.mutedFg : c.fg,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s2),
        LayoutBuilder(
          builder: (context, box) {
            return Semantics(
              label: 'Heart rate chart, ${d.min} to ${d.max} bpm',
              child: GestureDetector(
                onTapDown: (e) => _pick(e.localPosition, box.maxWidth),
                onHorizontalDragUpdate: (e) =>
                    _pick(e.localPosition, box.maxWidth),
                onHorizontalDragEnd: (_) {},
                child: RepaintBoundary(
                  child: SizedBox(
                    height: widget.height,
                    width: box.maxWidth,
                    child: DrawIn(
                      builder: (_, t) =>
                          CustomPaint(painter: _HeartDayPainter(d, c, t, sp)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Space.s2),
        LayoutBuilder(
          builder: (context, box) {
            return SizedBox(
              width: box.maxWidth - _padR,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final h in [0, 6, 12, 18])
                    Text(
                      hourLabel(d.start.add(Duration(hours: h))),
                      style: TextStyle(color: c.mutedFg, fontSize: 12),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeartDayPainter extends CustomPainter {
  _HeartDayPainter(this.d, this.c, this.t, this.scrub);
  final HeartDay d;
  final AppColors c;
  final double t;
  final HrPoint? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final s = _scale(d.limits, d.max ?? 0);
    double y(num v) => size.height - (v - s.lo) / (s.hi - s.lo) * size.height;
    final plotW = size.width - _padR;
    double x(DateTime tm) =>
        tm.difference(d.start).inMilliseconds /
        d.end.difference(d.start).inMilliseconds *
        plotW;
    _zoneLines(canvas, size, d.limits, y, c);
    if (d.points.isEmpty) return;
    // Break the line where the tracker was off for more than 15 minutes.
    final path = Path();
    for (var i = 0; i < d.points.length; i++) {
      final p = d.points[i];
      final gap = i == 0 || p.t.difference(d.points[i - 1].t).inMinutes > 15;
      gap ? path.moveTo(x(p.t), y(p.avg)) : path.lineTo(x(p.t), y(p.avg));
    }
    final reveal = Rect.fromLTWH(0, -20, plotW * t, size.height + 40);
    final bands = [
      (Zone.light, y(d.limits.moderate), size.height + 20),
      (Zone.moderate, y(d.limits.vigorous), y(d.limits.moderate)),
      (Zone.vigorous, y(d.limits.peak), y(d.limits.vigorous)),
      (Zone.peak, -20.0, y(d.limits.peak)),
    ];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (final (z, top, bottom) in bands) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, top, plotW, bottom).intersect(reveal));
      canvas.drawPath(path, stroke..color = zoneColor(c, z));
      canvas.restore();
    }
    if (scrub != null) {
      final sx = x(scrub!.t);
      canvas.drawLine(
        Offset(sx, 0),
        Offset(sx, size.height),
        Paint()
          ..color = c.mutedFg
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(sx, y(scrub!.avg)),
        6.5,
        Paint()..color = c.card,
      );
      canvas.drawCircle(
        Offset(sx, y(scrub!.avg)),
        5,
        Paint()..color = zoneColor(c, d.limits.zoneOf(scrub!.avg)),
      );
    }
  }

  @override
  bool shouldRepaint(_HeartDayPainter o) =>
      o.t != t || o.scrub != scrub || o.c != c || o.d != d;
}

class HeartWeekChart extends StatelessWidget {
  const HeartWeekChart({super.key, required this.week, this.height = 230});
  final HeartWeek week;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: week.days
          .map((d) => '${weekday(d.date)} ${d.min} to ${d.max} bpm')
          .join(', '),
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: DrawIn(
                duration: const Duration(milliseconds: 900),
                curve: Curves.linear,
                builder: (_, t) =>
                    CustomPaint(painter: _WeekPainter(week, c, t)),
              ),
            ),
            const SizedBox(height: Space.s2),
            LayoutBuilder(
              builder: (context, box) {
                return SizedBox(
                  width: box.maxWidth - _padR,
                  child: Row(
                    children: [
                      for (final d in week.days)
                        Expanded(
                          child: Text(
                            weekday(d.date),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.mutedFg, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter(this.w, this.c, this.t);
  final HeartWeek w;
  final AppColors c;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final max = w.days.isEmpty ? 0 : w.days.map((d) => d.max).reduce(math.max);
    final s = _scale(w.limits, max);
    double y(num v) => size.height - (v - s.lo) / (s.hi - s.lo) * size.height;
    _zoneLines(canvas, size, w.limits, y, c);
    final step = (size.width - _padR) / math.max(w.days.length, 1);
    for (var i = 0; i < w.days.length; i++) {
      final d = w.days[i];
      final local = Curves.easeOutBack.transform(
        ((t * (w.days.length + 5) - i) / 6).clamp(0.0, 1.0),
      );
      final cx = step * i + step / 2, mid = y(d.avg);
      final top = mid + (y(d.max) - mid) * local,
          bottom = mid + (y(d.min) - mid) * local;
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, bottom),
        Paint()
          ..color = c.zLight
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(cx, mid), 3, Paint()..color = c.card);
    }
  }

  @override
  bool shouldRepaint(_WeekPainter o) => o.t != t || o.c != c;
}

// ---------- Sleep stages ----------
class Hypnogram extends StatelessWidget {
  const Hypnogram({super.key, required this.night});
  final SleepNight night;

  static const _lane = 26.0, _gap = 34.0, _top = 20.0;
  static const lanes = ['Awake', 'Restlessness', 'REM', 'Light', 'Deep'];

  @override
  Widget build(BuildContext context) {
    final c = context.c, n = night;
    final restless = n.restless
        .where((r) => !r.start.isBefore(n.start) && !r.end.isAfter(n.end))
        .toList();
    double of(Stage s) =>
        n.stages.where((x) => x.stage == s).fold(0.0, (a, x) => a + x.minutes);
    final totals = [
      of(Stage.awake),
      restless.fold(0.0, (a, r) => a + r.minutes),
      of(Stage.rem),
      of(Stage.light),
      of(Stage.deep),
    ];
    final h = _top + lanes.length * (_lane + _gap) - _gap + 4;
    final mid = n.start.add(n.end.difference(n.start) ~/ 2);
    return Column(
      children: [
        Semantics(
          label:
              'Sleep from ${clock(n.start)} to ${clock(n.end)}. ${[for (var i = 0; i < 5; i++) '${lanes[i]} ${dur(totals[i])}'].join(', ')}.',
          child: ExcludeSemantics(
            child: SizedBox(
              height: h,
              width: double.infinity,
              child: DrawIn(
                duration: const Duration(milliseconds: 1000),
                builder: (_, t) => CustomPaint(
                  painter: _HypnoPainter(n, restless, totals, c, t),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _when(
                context,
                clock(n.start),
                'Went to bed',
                CrossAxisAlignment.start,
              ),
            ),
            Text(clock(mid), style: mono(context, size: 13)),
            Expanded(
              child: _when(
                context,
                clock(n.end),
                'Out of bed',
                CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _when(
    BuildContext context,
    String t,
    String label,
    CrossAxisAlignment a,
  ) => Column(
    crossAxisAlignment: a,
    children: [
      Text(t, style: mono(context, size: 13)),
      Text(label, style: TextStyle(color: context.c.mutedFg, fontSize: 12)),
    ],
  );
}

class _HypnoPainter extends CustomPainter {
  _HypnoPainter(this.n, this.restless, this.totals, this.c, this.t);
  final SleepNight n;
  final List<Span> restless;
  final List<double> totals;
  final AppColors c;
  final double t;

  static double laneY(int i) =>
      Hypnogram._top + i * (Hypnogram._lane + Hypnogram._gap);
  static int laneOf(Stage s) => switch (s) {
    Stage.awake => 0,
    Stage.rem => 2,
    Stage.light => 3,
    Stage.deep => 4,
  };

  @override
  void paint(Canvas canvas, Size size) {
    const lane = Hypnogram._lane;
    final total = n.end.difference(n.start).inMilliseconds;
    double x(DateTime tm) =>
        tm.difference(n.start).inMilliseconds / total * size.width;
    final colors = [c.sAwake, c.sRestless, c.sRem, c.sLight, c.sDeep];
    for (var i = 0; i < 5; i++) {
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: Hypnogram.lanes[i],
              style: TextStyle(
                color: c.fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: kSans,
              ),
            ),
            TextSpan(
              text: ' · ${dur(totals[i])}',
              style: TextStyle(
                color: c.mutedFg,
                fontSize: 13,
                fontFamily: kSans,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, laneY(i) - tp.height - 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, laneY(i), size.width, lane),
          const Radius.circular(lane / 2),
        ),
        Paint()..color = c.track,
      );
    }
    final st = [...n.stages]..sort((a, b) => a.start.compareTo(b.start));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    // Thin lines joining one stage to the next.
    final join = Paint()
      ..color = c.mutedFg.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < st.length; i++) {
      final a = laneY(laneOf(st[i - 1].stage)) + lane / 2,
          b = laneY(laneOf(st[i].stage)) + lane / 2;
      canvas.drawLine(
        Offset(x(st[i].start), math.min(a, b)),
        Offset(x(st[i].start), math.max(a, b)),
        join,
      );
    }
    for (final s in st) {
      final w = math.max(x(s.end) - x(s.start), 2.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x(s.start), laneY(laneOf(s.stage)), w, lane),
          Radius.circular(math.min(8, w / 2)),
        ),
        Paint()..color = colors[laneOf(s.stage)],
      );
    }
    for (final r in restless) {
      final w = math.max(x(r.end) - x(r.start), 2.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x(r.start), laneY(1) + 4, w, lane - 8),
          const Radius.circular(1.5),
        ),
        Paint()..color = c.sRestless,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HypnoPainter o) => o.t != t || o.c != c || o.n != n;
}

// ---------- Sleep quality bar ----------
class QualityBar extends StatelessWidget {
  const QualityBar({
    super.key,
    required this.pos,
    required this.bandFrom,
    required this.bandTo,
    required this.color,
  });
  final double pos, bandFrom, bandTo;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: DrawIn(
          builder: (_, t) => CustomPaint(
            painter: _QualityPainter(pos * t, bandFrom, bandTo, color, c),
          ),
        ),
      ),
    );
  }
}

class _QualityPainter extends CustomPainter {
  _QualityPainter(this.pos, this.from, this.to, this.color, this.c);
  final double pos, from, to;
  final Color color;
  final AppColors c;
  @override
  void paint(Canvas canvas, Size size) {
    const h = 14.0;
    final top = (size.height - h) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, h),
        const Radius.circular(h / 2),
      ),
      Paint()..color = c.track,
    );
    if (pos > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, math.max(size.width * pos, h), h),
          const Radius.circular(h / 2),
        ),
        Paint()..color = color,
      );
    }
    // Dashed outline of the typical range.
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * from,
        top - 4,
        math.max(size.width * (to - from), 12),
        h + 8,
      ),
      const Radius.circular(99),
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c.mutedFg.withValues(alpha: 0.75);
    for (final m in (Path()..addRRect(band)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), dash);
      }
    }
    final kx = (size.width * pos).clamp(9.0, size.width - 9);
    canvas.drawCircle(
      Offset(kx, size.height / 2),
      10,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(Offset(kx, size.height / 2), 9, Paint()..color = c.card);
    canvas.drawCircle(
      Offset(kx, size.height / 2),
      7,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_QualityPainter o) => o.pos != pos || o.c != c;
}
