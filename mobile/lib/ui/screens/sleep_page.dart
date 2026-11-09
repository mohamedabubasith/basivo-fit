import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/sleep_quality.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../charts/charts.dart';
import '../widgets/common.dart';

/// The easy-to-read sleep view: a summary with a goal ring, the night in one
/// strip, each stage against its typical range, three checks and the week.
class SleepView extends StatefulWidget {
  const SleepView({super.key, required this.h});
  final Health h;
  @override
  State<SleepView> createState() => _SleepViewState();
}

class _SleepViewState extends State<SleepView> {
  int? _i;

  @override
  Widget build(BuildContext context) {
    final nights = widget.h.sleep.where((n) => !n.isNap).toList();
    if (nights.isEmpty) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle('Sleep', icon: LucideIcons.moon),
            SizedBox(height: Space.s2),
            Muted(
              'No sleep recorded yet. Wear your tracker to bed to see your night here.',
            ),
          ],
        ),
      );
    }
    final i = (_i ?? nights.length - 1).clamp(0, nights.length - 1);
    final n = nights[i];
    final last = i == nights.length - 1;
    const gap = SizedBox(height: Space.s4);
    return AnimatedSwitcher(
      duration: Motion.base,
      child: Column(
        key: ValueKey(i),
        children: [
          _Hero(
            night: n,
            title: last ? 'Last night' : longDate(n.end),
            onPrev: i > 0 ? () => setState(() => _i = i - 1) : null,
            onNext: last ? null : () => setState(() => _i = i + 1),
          ),
          if (n.stages.isNotEmpty) ...[gap, _NightStrip(night: n)],
          gap,
          _Stages(night: n),
          if (n.stages.isNotEmpty) ...[gap, _Checks(night: n)],
          if (nights.length > 1) ...[
            gap,
            _Week(
              nights: nights,
              selected: i,
              onSelect: (k) => setState(() => _i = k),
            ),
          ],
        ],
      ),
    );
  }
}

const _goalMin = 7 * 60;

class _Hero extends StatelessWidget {
  const _Hero({
    required this.night,
    required this.title,
    this.onPrev,
    this.onNext,
  });
  final SleepNight night;
  final String title;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.c, n = night;
    final inBed = n.end.difference(n.start).inMinutes;
    final short = _goalMin - n.minutes;
    return AppCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.7],
        colors: [c.accent.withValues(alpha: 0.18), c.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.moon, size: 18, color: c.fg),
              const SizedBox(width: Space.s2),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconBtn(
                icon: LucideIcons.chevronLeft,
                label: 'Earlier night',
                onTap: onPrev,
                round: true,
              ),
              IconBtn(
                icon: LucideIcons.chevronRight,
                label: 'Later night',
                onTap: onNext,
                round: true,
              ),
            ],
          ),
          const SizedBox(height: Space.s3),
          Row(
            children: [
              _GoalRing(minutes: n.minutes),
              const SizedBox(width: Space.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dur(n.minutes), style: mono(context, size: 34)),
                    const Muted('asleep', size: 13),
                    const SizedBox(height: Space.s2),
                    Text(
                      '${clock(n.start)} → ${clock(n.end)}',
                      style: mono(context, size: 14),
                    ),
                    Muted('${dur(inBed)} in bed', size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s3),
          Pill(
            short > 0 ? '${dur(short)} short of 7h' : 'Reached 7h or more',
            fg: short > 0 ? c.warn : c.up,
            bg: short > 0 ? c.warnBg : c.upBg,
          ),
          const SizedBox(height: Space.s3),
          Text(sleepVerdict(n), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.minutes});
  final int minutes;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = (minutes / _goalMin).clamp(0.0, 1.0);
    return Semantics(
      label: '${(p * 100).round()} percent of a 7 hour night',
      child: SizedBox.square(
        dimension: 96,
        child: DrawIn(
          builder: (_, t) => CustomPaint(
            painter: _RingPainter(p * t, c.track, c.accent, c.sRem),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(p * 100 * t).round()}%',
                    style: mono(context, size: 20),
                  ),
                  const Muted('of 7h', size: 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.track, this.a, this.b);
  final double p;
  final Color track, a, b;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (p <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [a, b, a],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.p != p || o.a != a;
}

Color _stageColor(AppColors c, Stage s) => switch (s) {
  Stage.deep => c.sDeep,
  Stage.rem => c.sRem,
  Stage.light => c.sLight,
  Stage.awake => c.sAwake,
};

/// The whole night as one colour strip, left (bedtime) to right (wake up).
class _NightStrip extends StatelessWidget {
  const _NightStrip({required this.night});
  final SleepNight night;
  @override
  Widget build(BuildContext context) {
    final c = context.c, n = night;
    final mid = n.start.add(n.end.difference(n.start) ~/ 2);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Your night'),
          const SizedBox(height: Space.s1),
          const Muted(
            'From going to bed (left) to waking up (right).',
            size: 12,
          ),
          const SizedBox(height: Space.s3),
          Semantics(
            label:
                'Night from ${clock(n.start)} to ${clock(n.end)}, coloured by sleep stage',
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: DrawIn(
                    builder: (_, t) =>
                        CustomPaint(painter: _StripPainter(n, c, t)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s2),
          Row(
            children: [
              Text(clock(n.start), style: mono(context, size: 12)),
              const Spacer(),
              Text(
                clock(mid),
                style: mono(context, size: 12, color: c.mutedFg),
              ),
              const Spacer(),
              Text(clock(n.end), style: mono(context, size: 12)),
            ],
          ),
          const SizedBox(height: Space.s3),
          Wrap(
            spacing: Space.s3,
            runSpacing: Space.s2,
            children: [
              for (final (s, name) in [
                (Stage.awake, 'Awake'),
                (Stage.rem, 'REM'),
                (Stage.light, 'Light'),
                (Stage.deep, 'Deep'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _stageColor(c, s),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(name, style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.n, this.c, this.t);
  final SleepNight n;
  final AppColors c;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.track);
    final total = n.end.difference(n.start).inSeconds;
    if (total <= 0) return;
    final shown = size.width * t;
    for (final s in n.stages) {
      final x0 = s.start.difference(n.start).inSeconds / total * size.width;
      final x1 = s.end.difference(n.start).inSeconds / total * size.width;
      if (x0 > shown) continue;
      canvas.drawRect(
        Rect.fromLTRB(x0, 0, math.min(x1, shown) + 0.5, size.height),
        Paint()..color = _stageColor(c, s.stage),
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter o) => o.t != t || o.n != n || o.c != c;
}

/// Each stage: time, share, a bar with the typical range and a plain meaning.
class _Stages extends StatelessWidget {
  const _Stages({required this.night});
  final SleepNight night;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Sleep stages'),
          const SizedBox(height: Space.s1),
          const Muted(
            'The light band on each bar is the typical range for adults.',
            size: 12,
          ),
          const SizedBox(height: Space.s4),
          for (final s in stageStats(night)) ...[
            MergeSemantics(
              child: _StageRow(s: s, color: _stageColor(c, s.stage)),
            ),
            const SizedBox(height: Space.s4),
          ],
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.s, required this.color});
  final StageStat s;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, fg, bg) = switch (s.level) {
      Level.typical => ('Typical', c.up, c.upBg),
      Level.low => ('Low', c.warn, c.warnBg),
      Level.high => ('High', c.warn, c.warnBg),
    };
    const scale = 70.0; // bar shows 0 to 70%
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Space.s2),
            Text(
              s.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: Space.s2),
            Text(dur(s.minutes), style: mono(context, size: 14)),
            Text(
              '  ${s.pct.round()}%',
              style: mono(context, size: 13, color: c.mutedFg),
            ),
            const Spacer(),
            Pill(label, fg: fg, bg: bg),
          ],
        ),
        const SizedBox(height: Space.s2),
        SizedBox(
          height: 10,
          child: LayoutBuilder(
            builder: (_, box) {
              final w = box.maxWidth;
              return DrawIn(
                builder: (_, t) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: c.track,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Positioned(
                      left: w * s.from / scale,
                      width: w * (s.to - s.from) / scale,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.fg.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Container(
                      width: (w * (s.pct / scale).clamp(0.0, 1.0) * t).clamp(
                        0.0,
                        w,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.s1),
        Muted(
          '${s.meaning} Typical: ${s.from.round() == 0 ? 'under ${s.to.round()}' : '${s.from.round()} to ${s.to.round()}'}%.',
          size: 12,
        ),
      ],
    );
  }
}

class _Checks extends StatelessWidget {
  const _Checks({required this.night});
  final SleepNight night;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Quick checks'),
          const SizedBox(height: Space.s3),
          for (final k in sleepChecks(night))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: k.ok ? c.upBg : c.warnBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        k.ok ? LucideIcons.check : LucideIcons.triangleAlert,
                        size: 15,
                        color: k.ok ? c.up : c.warn,
                        semanticLabel: k.ok ? 'Good' : 'Worth a look',
                      ),
                    ),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Muted(k.detail, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Muted(
            'Simple, open rules from your sleep stages. Google\'s sleep score uses a private formula.',
            size: 11,
          ),
        ],
      ),
    );
  }
}

/// Hours slept per night with a 7-hour goal line. Tap a bar to open that night.
class _Week extends StatelessWidget {
  const _Week({
    required this.nights,
    required this.selected,
    required this.onSelect,
  });
  final List<SleepNight> nights;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final from = math.max(0, nights.length - 7);
    final shown = nights.sublist(from);
    final avg = shown.fold(0, (a, n) => a + n.minutes) / shown.length;
    const maxMin = 10 * 60.0, chartH = 120.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            'Your week',
            trailing: Text(
              'avg ${dur(avg)}',
              style: mono(context, size: 13, color: c.mutedFg),
            ),
          ),
          const SizedBox(height: Space.s4),
          SizedBox(
            height: chartH + 22,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: chartH * (1 - _goalMin / maxMin),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: c.fg.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '7h',
                        style: mono(context, size: 11, color: c.mutedFg),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var k = 0; k < shown.length; k++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: from + k == selected,
                            label:
                                '${weekday(shown[k].end)}, ${dur(shown[k].minutes)}',
                            child: GestureDetector(
                              onTap: () => onSelect(from + k),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  DrawIn(
                                    delay: k * 0.05,
                                    builder: (_, t) => Container(
                                      width: 22,
                                      height: math.max(
                                        4,
                                        chartH *
                                            (shown[k].minutes / maxMin).clamp(
                                              0.0,
                                              1.0,
                                            ) *
                                            t,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: from + k == selected
                                            ? c.accent
                                            : c.accent.withValues(
                                                alpha:
                                                    shown[k].minutes >= _goalMin
                                                    ? 0.6
                                                    : 0.3,
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    weekday(shown[k].end).substring(0, 1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: from + k == selected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: from + k == selected
                                          ? c.fg
                                          : c.mutedFg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s2),
          Muted(
            '${shown.where((n) => n.minutes >= _goalMin).length} of ${shown.length} nights reached 7 hours. Tap a bar to see that night.',
            size: 12,
          ),
        ],
      ),
    );
  }
}
