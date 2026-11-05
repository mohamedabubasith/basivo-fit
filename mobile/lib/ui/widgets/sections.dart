import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/sleep_quality.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../charts/charts.dart';
import 'common.dart';
import 'motion.dart';
import 'pulse.dart';

String ago(DateTime at) {
  final m = DateTime.now().difference(at).inMinutes;
  return m <= 1 ? 'just now' : '$m min ago';
}

class TipCard extends StatelessWidget {
  const TipCard({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, 0.7], colors: [c.accent.withValues(alpha: 0.16), c.card]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Twinkle(),
        const SizedBox(width: Space.s3),
        Expanded(child: Text(dailyTip(h), style: Theme.of(context).textTheme.bodyLarge)),
      ]),
    );
  }
}

class _Twinkle extends StatefulWidget {
  const _Twinkle();
  @override
  State<_Twinkle> createState() => _TwinkleState();
}

class _TwinkleState extends State<_Twinkle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.rotate(angle: 0.2 * Curves.easeInOut.transform(_c.value), child: Opacity(opacity: 1 - 0.4 * _c.value, child: child)),
          child: Icon(LucideIcons.sparkles, size: 18, color: dark ? const Color(0xFFC4B5FD) : context.c.accent),
        ),
      ),
    );
  }
}

class DeviceStrip extends StatelessWidget {
  const DeviceStrip({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    if (h.devices.isEmpty) return const SizedBox.shrink();
    final d = h.devices.first, c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.border), boxShadow: c.shadow),
        child: Wrap(spacing: Space.s2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ExcludeSemantics(child: Icon(LucideIcons.batteryMedium, size: 16, color: c.fg)),
          Text('${d.name}${d.battery != null ? ' · ${d.battery}%' : ''}', style: const TextStyle(fontSize: 14)),
          if (d.lastSync != null) Text('synced ${clock(d.lastSync!)}', style: TextStyle(fontSize: 14, color: c.mutedFg)),
        ]),
      ),
    );
  }
}

class HeartCard extends StatelessWidget {
  const HeartCard({super.key, required this.h, this.onTap});
  final Health h;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c, now = h.now;
    final lastRest = h.resting.isEmpty ? null : h.resting.last.value;
    final lastHrv = h.hrv.isEmpty ? null : h.hrv.last.value;
    return Pressable(
      onTap: onTap,
      semanticLabel: onTap == null ? null : 'Heart rate details',
      child: AppCard(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, 0.55], colors: [c.heartBg, c.card]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardTitle('Heart rate'),
          const SizedBox(height: Space.s3),
          Row(children: [
            BeatingHeart(bpm: now?.bpm ?? 0),
            const SizedBox(width: Space.s4),
            Expanded(
              child: MergeSemantics(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    CountUp(value: (now?.bpm ?? 0).toDouble(), builder: (_, v) => Text(now == null ? '--' : '${v.round()}', style: mono(context, size: 34))),
                    Text(' bpm', style: TextStyle(fontSize: 16, color: c.mutedFg)),
                  ]),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: now == null ? 'No reading yet' : 'Latest reading ${clock(now.at)}'),
                    if (now != null && h.live) TextSpan(text: ' · ${ago(now.at)}', style: const TextStyle(fontSize: 12)),
                  ]), style: TextStyle(color: c.mutedFg, fontSize: 14)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: Space.s2),
          EcgLine(bpm: now?.bpm ?? 60),
          const SizedBox(height: Space.s2),
          Divider(height: 1, color: c.border),
          const SizedBox(height: Space.s3),
          Row(children: [
            _kv(context, 'Resting', lastRest == null ? '--' : '$lastRest bpm'),
            _kv(context, 'Highest today', h.todayRange == null ? '--' : '${h.todayRange!.max} bpm'),
            _kv(context, 'HRV', lastHrv == null ? '--' : '$lastHrv ms'),
          ]),
        ]),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Expanded(
        child: MergeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(fontSize: 12, color: context.c.mutedFg)),
            const SizedBox(height: 2),
            Text(v, style: mono(context, size: 15)),
          ]),
        ),
      );
}

class StepsCard extends StatelessWidget {
  const StepsCard({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final left = (h.stepGoal - h.stepsToday).clamp(0, 1 << 30);
    final ring = Ring(
      value: h.stepsToday.toDouble(),
      max: h.stepGoal.toDouble(),
      child: MergeSemantics(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(LucideIcons.footprints, size: 20, color: c.mutedFg)),
          CountUp(value: h.stepsToday.toDouble(), builder: (_, v) => Text(num0(v), style: mono(context, size: 26))),
          Text('of ${num0(h.stepGoal)}', style: TextStyle(color: c.mutedFg, fontSize: 14)),
        ]),
      ),
    );
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CardTitle('Steps today'),
      const SizedBox(height: Space.s1),
      Muted(left > 0 ? '${num0(left)} more to reach your goal.' : 'Goal reached. Well done.'),
      const SizedBox(height: Space.s3),
      _stat(context, LucideIcons.mapPin, 'Distance', '${h.distanceKm} km'),
      _stat(context, LucideIcons.flame, 'Active cal', num0(h.activeKcal)),
      _stat(context, LucideIcons.zap, 'Zone min', '${h.azm.total}'),
    ]);
    return AppCard(
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 300) return Column(children: [ring, const SizedBox(height: Space.s4), info]);
        return Row(children: [ring, const SizedBox(width: Space.s5), Expanded(child: info)]);
      }),
    );
  }

  Widget _stat(BuildContext context, IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s3),
        child: MergeSemantics(
          child: Row(children: [
            ExcludeSemantics(child: Icon(i, size: 18, color: context.c.mutedFg)),
            const SizedBox(width: Space.s2),
            Expanded(child: Muted(k)),
            Text(v, style: mono(context, size: 15)),
          ]),
        ),
      );
}

class DayStats extends StatelessWidget {
  const DayStats({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    final r = h.todayRange;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text('Today at a glance', style: Theme.of(context).textTheme.titleMedium)),
      const SizedBox(height: Space.s2),
      TileGrid(children: [
        Tile(icon: LucideIcons.flame, label: 'Calories burned', value: h.totalKcal == null ? '--' : num0(h.totalKcal!), sub: Text('${num0(h.activeKcal)} from activity')),
        Tile(icon: LucideIcons.heartPulse, label: 'Heart rate', value: r == null ? '--' : '${r.min} to ${r.max}', sub: Text(r == null ? 'No readings yet' : 'bpm today, average ${r.avg}')),
        Tile(icon: LucideIcons.clock, label: 'Hourly activity', value: '${h.hourlyDone} of ${Health.hourlyGoal}', sub: const Text('hours with 250+ steps, 9 AM to 6 PM')),
        Tile(icon: LucideIcons.dumbbell, label: 'Exercise days', value: '${h.exerciseDays} of ${Health.exerciseGoal}', sub: const Text('this week')),
      ]),
    ]);
  }
}

class SleepSummaryCard extends StatelessWidget {
  const SleepSummaryCard({super.key, required this.h, this.full = false, this.onTap});
  final Health h;
  final bool full;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c, night = h.mainSleep;
    if (night == null) {
      return const AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Sleep', icon: LucideIcons.moon),
        SizedBox(height: Space.s2),
        Muted('No sleep recorded yet. Wear your tracker to bed to see your sleep stages.'),
      ]));
    }
    final nights = h.sleep.where((n) => !n.isNap).toList();
    final naps = h.sleep.where((n) => n.isNap).toList();
    final avg = nights.isEmpty ? 0 : nights.fold(0, (a, n) => a + n.minutes) / nights.length;
    final stages = [('Deep', night.deep, c.sDeep), ('Light', night.light, c.sLight), ('REM', night.rem, c.sRem), ('Awake', night.awake, c.sAwake)];
    final total = stages.fold(0, (a, s) => a + s.$2).clamp(1, 1 << 30);
    final w = night.longestWake;
    return Pressable(
      onTap: onTap,
      semanticLabel: onTap == null ? null : 'Sleep details',
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardTitle('Last night', icon: LucideIcons.moon, trailing: Text('${clock(night.start)} to ${clock(night.end)}', style: mono(context, size: 13, color: c.mutedFg))),
          const SizedBox(height: Space.s3),
          Text(hm(night.minutes), style: mono(context, size: 26)),
          if (w != null && w.minutes >= 20) ...[
            const SizedBox(height: Space.s2),
            Pill('Awake ${w.minutes} min around ${clock(w.at)}', fg: c.warn, bg: c.warnBg),
          ],
          if (nights.length > 1) ...[const SizedBox(height: Space.s2), Muted('Average ${hm(avg)} over ${nights.length} nights')],
          const SizedBox(height: Space.s3),
          Semantics(
            label: stages.map((s) => '${s.$1} ${s.$2} minutes').join(', '),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 12,
                  child: DrawIn(
                    duration: const Duration(milliseconds: 900),
                    builder: (_, t) => Row(children: [
                      for (final s in stages)
                        Flexible(
                          flex: (s.$2 * 1000 ~/ total).clamp(1, 1000),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: t, child: Container(color: s.$3)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s3),
          TileLegend(items: [for (final s in stages) (s.$1, '${s.$2} min', s.$3)]),
          if (full && nights.length > 1) ...[
            const SizedBox(height: Space.s4),
            Bars(data: [for (final n in nights) double.parse((n.minutes / 60).toStringAsFixed(1))], labels: [for (final n in nights) n.date], goal: 7, format: (v) => '$v h', height: 120),
          ],
          if (full && naps.isNotEmpty) ...[const SizedBox(height: Space.s2), Muted('Naps: ${naps.map((n) => '${n.date} ${clock(n.start)}, ${n.minutes} min').join(' · ')}')],
        ]),
      ),
    );
  }
}

class TileLegend extends StatelessWidget {
  const TileLegend({super.key, required this.items});
  final List<(String, String, Color)> items;
  @override
  Widget build(BuildContext context) {
    Widget cell((String, String, Color) it) => MergeSemantics(
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: it.$3, shape: BoxShape.circle)),
            const SizedBox(width: Space.s2),
            Text(it.$1, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(it.$2, style: mono(context, size: 13, color: context.c.mutedFg)),
          ]),
        );
    return Column(children: [
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s2),
          child: Row(children: [
            Expanded(child: cell(items[i])),
            const SizedBox(width: Space.s4),
            Expanded(child: i + 1 < items.length ? cell(items[i + 1]) : const SizedBox()),
          ]),
        ),
    ]);
  }
}

class Vitals extends StatelessWidget {
  const Vitals({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rest = h.resting.isEmpty ? null : h.resting.last.value;
    final hrv = h.hrv.isEmpty ? null : h.hrv.last.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text('Body and vitals', style: Theme.of(context).textTheme.titleMedium)),
      const SizedBox(height: Space.s2),
      TileGrid(children: [
        Tile(icon: LucideIcons.droplets, label: 'Blood oxygen', value: h.spo2 == null ? '--' : '${h.spo2!.avg}%',
            sub: Text(h.spo2 == null ? 'No data yet' : '${h.spo2!.low} to ${h.spo2!.high}% overnight')),
        Tile(icon: LucideIcons.wind, label: 'Breathing rate', value: h.respRate == null ? '--' : '${h.respRate}', sub: const Text('breaths per minute')),
        Tile(icon: LucideIcons.thermometer, label: 'Skin temp', value: h.skinTempC == null ? '--' : '${h.skinTempC}°C', sub: const Text('during sleep')),
        Tile(icon: LucideIcons.scale, label: 'Weight', value: h.weightKg == null ? '--' : '${h.weightKg} kg', sub: const Text('last logged')),
        Tile(icon: LucideIcons.activity, label: 'Resting heart', value: rest == null ? '--' : '$rest bpm',
            sub: h.resting.length > 1 ? Sparkline(data: [for (final r in h.resting) r.value.toDouble()], color: c.down, height: 22) : const Text('trend builds daily')),
        Tile(icon: LucideIcons.zap, label: 'HRV', value: hrv == null ? '--' : '$hrv ms',
            sub: h.hrv.length > 1 ? Sparkline(data: [for (final r in h.hrv) r.value], color: c.up, height: 22) : const Text('trend builds daily')),
      ]),
    ]);
  }
}

class WeekSteps extends StatelessWidget {
  const WeekSteps({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    if (h.stepsWeek.length < 2) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Steps by day'),
        const SizedBox(height: Space.s4),
        Bars(data: [for (final d in h.stepsWeek) d.value.toDouble()], labels: [for (final d in h.stepsWeek) weekday(d.date)], goal: h.stepGoal.toDouble()),
      ]),
    );
  }
}

class HourlyCard extends StatelessWidget {
  const HourlyCard({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    if (h.hourSteps.length < 2) return const SizedBox.shrink();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Steps by hour', icon: LucideIcons.clock, trailing: Text('${h.hourlyDone} of ${Health.hourlyGoal}', style: mono(context, size: 15, weight: FontWeight.w600))),
        const SizedBox(height: Space.s1),
        const Muted('Aim for 250 steps every hour from 9 AM to 6 PM.'),
        const SizedBox(height: Space.s4),
        Bars(
          data: [for (final x in h.hourSteps) x.value.toDouble()],
          labels: [for (var i = 0; i < h.hourSteps.length; i++) i % 4 == 0 ? hourLabel(h.hourSteps[i].date) : ''],
          goal: 250,
          height: 120,
          semanticsLabel: h.hourSteps.map((x) => '${hourLabel(x.date)} ${x.value} steps').join(', '),
        ),
      ]),
    );
  }
}

class AzmCard extends StatelessWidget {
  const AzmCard({super.key, required this.h});
  final Health h;
  @override
  Widget build(BuildContext context) {
    final c = context.c, z = h.azm;
    final rows = [('Fat burn', z.fatBurn, c.warn), ('Cardio', z.cardio, const Color(0xFFF97316)), ('Peak', z.peak, c.heart)];
    final max = [1, ...rows.map((r) => r.$2)].reduce((a, b) => a > b ? a : b);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardTitle('Active Zone Minutes', icon: LucideIcons.zap, trailing: Text('${z.total}', style: mono(context, size: 15, weight: FontWeight.w600))),
        const SizedBox(height: Space.s1),
        const Muted('Cardio and peak minutes count double.'),
        const SizedBox(height: Space.s3),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: MergeSemantics(
              child: Row(children: [
                SizedBox(width: 72, child: Text(r.$1, style: const TextStyle(fontSize: 14))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 10,
                      color: c.track,
                      alignment: Alignment.centerLeft,
                      child: DrawIn(builder: (_, t) => FractionallySizedBox(widthFactor: r.$2 / max * t, child: Container(decoration: BoxDecoration(color: r.$3, borderRadius: BorderRadius.circular(99))))),
                    ),
                  ),
                ),
                SizedBox(width: 64, child: Text('${r.$2} min', textAlign: TextAlign.right, style: mono(context, size: 13))),
              ]),
            ),
          ),
      ]),
    );
  }
}
