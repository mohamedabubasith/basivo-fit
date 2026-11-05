import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/demo.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/sleep_quality.dart';
import '../../state/health_store.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../charts/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/sections.dart';
import 'live.dart';
import 'page.dart';

List<Widget> _loading(String title, ThemeController theme) => [
  TabHeader(title: title, theme: theme),
  const Skeleton(height: 220),
  const Skeleton(height: 160),
];

class TodayTab extends StatelessWidget {
  const TodayTab({super.key, required this.theme, required this.goTo});
  final ThemeController theme;
  final void Function(int) goTo;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), h = s.health;
    if (h == null) return TabPage(children: _loading('Today', theme));
    final hour = DateTime.now().hour;
    final first = (s.user?.name ?? '').split(' ').first;
    final greet =
        '${hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening'}${first.isEmpty ? '' : ', $first'}';
    return TabPage(
      onRefresh: s.reload,
      children: [
        TabHeader(title: greet, theme: theme),
        DeviceStrip(h: h),
        TipCard(h: h),
        HeartCard(h: h, onTap: () => goTo(1)),
        StepsCard(h: h),
        DayStats(h: h),
        SleepSummaryCard(h: h, onTap: () => goTo(2)),
        Vitals(h: h),
        if (s.demo)
          const Muted(
            'You are viewing demo data. Sign in with Google on the Profile tab to see your own.',
            size: 12,
            align: TextAlign.center,
          ),
      ],
    );
  }
}

// ---------------- Heart ----------------
class HeartTab extends StatelessWidget {
  const HeartTab({super.key, required this.theme});
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), h = s.health;
    if (h == null) return TabPage(children: _loading('Heart', theme));
    final c = context.c;
    return TabPage(
      onRefresh: s.reload,
      children: [
        TabHeader(title: 'Heart', theme: theme),
        HeartCard(h: h),
        const LiveHeartCard(),
        const HeartDetail(),
        if (h.resting.length > 1)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(
                  'Resting heart rate',
                  trailing: Text(
                    '${h.resting.last.value} bpm',
                    style: mono(context),
                  ),
                ),
                const SizedBox(height: Space.s3),
                Sparkline(
                  data: [for (final r in h.resting) r.value.toDouble()],
                  color: c.down,
                  height: 60,
                ),
                const SizedBox(height: Space.s3),
                const Muted(
                  'A lower resting heart rate usually means better fitness. Watch the trend, not single days.',
                ),
              ],
            ),
          ),
        if (h.hrv.length > 1)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(
                  'Heart rate variability',
                  trailing: Text(
                    '${h.hrv.last.value} ms',
                    style: mono(context),
                  ),
                ),
                const SizedBox(height: Space.s3),
                Sparkline(
                  data: [for (final r in h.hrv) r.value],
                  color: c.up,
                  height: 60,
                ),
                const SizedBox(height: Space.s3),
                const Muted(
                  'HRV is measured while you sleep. Higher than your usual level often means you are well rested.',
                ),
              ],
            ),
          ),
        const Muted(
          'Not medical advice. Talk to a doctor about any health concerns.',
          size: 12,
          align: TextAlign.center,
        ),
      ],
    );
  }
}

class HeartDetail extends StatefulWidget {
  const HeartDetail({super.key});
  @override
  State<HeartDetail> createState() => _HeartDetailState();
}

class _HeartDetailState extends State<HeartDetail> {
  bool week = false;
  int offset = 0;
  HeartDay? day;
  HeartWeek? wk;
  bool failed = false;
  int _req = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (day == null && wk == null) _load();
  }

  Future<void> _load() async {
    final s = StoreScope.read(context);
    final id = ++_req;
    setState(() {
      failed = false;
      if (week) {
        wk = null;
      } else {
        day = null;
      }
    });
    try {
      if (s.demo) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted || id != _req) return;
        setState(
          () => week ? wk = demoHeartWeek() : day = demoHeartDay(offset),
        );
      } else if (week) {
        final r = await s.api.heartWeek();
        if (mounted && id == _req) setState(() => wk = r);
      } else {
        final r = await s.api.heartDay(offset);
        if (mounted && id == _req) setState(() => day = r);
      }
    } catch (_) {
      if (mounted && id == _req) setState(() => failed = true);
    }
  }

  void _go(int o) {
    offset = o;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = week
        ? 'Last 7 days'
        : offset == 0
        ? 'Today'
        : offset == 1
        ? 'Yesterday'
        : longDate(DateTime.now().subtract(Duration(days: offset)));
    final limits = (week ? wk?.limits : day?.limits) ?? ZoneLimits.fallback;
    final lo = week
        ? (wk == null || wk!.days.isEmpty
              ? null
              : wk!.days.map((d) => d.min).reduce((a, b) => a < b ? a : b))
        : day?.min;
    final hi = week
        ? (wk == null || wk!.days.isEmpty
              ? null
              : wk!.days.map((d) => d.max).reduce((a, b) => a > b ? a : b))
        : day?.max;
    final ready = week ? wk != null : day != null;
    final zones = week ? wk?.zoneSeconds : day?.zoneSeconds;
    return Column(
      children: [
        Segmented<bool>(
          value: week,
          options: const [(false, 'Day', null), (true, 'Week', null)],
          onChanged: (v) {
            week = v;
            offset = 0;
            _load();
          },
        ),
        const SizedBox(height: Space.s4),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (!week) ...[
                    IconBtn(
                      icon: LucideIcons.chevronLeft,
                      label: 'Previous day',
                      onTap: () => _go(offset + 1),
                    ),
                    const SizedBox(width: Space.s2),
                    IconBtn(
                      icon: LucideIcons.chevronRight,
                      label: 'Next day',
                      onTap: offset == 0 ? null : () => _go(offset - 1),
                    ),
                    const SizedBox(width: Space.s2),
                    IconBtn(
                      icon: LucideIcons.rotateCcw,
                      label: 'Back to today',
                      onTap: offset == 0 ? null : () => _go(0),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.s3),
              AnimatedSize(
                duration: Motion.slow,
                curve: Motion.ease,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  child: KeyedSubtree(
                    key: ValueKey('$week-$offset-$ready-$failed'),
                    child: failed
                        ? const Muted(
                            'Could not load heart rate. Pull down to try again.',
                          )
                        : !ready
                        ? const Skeleton(height: 300)
                        : lo == null || hi == null
                        ? Muted(
                            'No heart rate recorded for this ${week ? 'week' : 'day'}.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MergeSemantics(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$lo–$hi',
                                      style: mono(
                                        context,
                                        size: 44,
                                      ).copyWith(letterSpacing: -1),
                                    ),
                                    Text(
                                      ' bpm',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: c.mutedFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Muted(
                                'High of $hi bpm in the ${zoneLabel[limits.zoneOf(hi)]!.toLowerCase()} zone',
                              ),
                              const SizedBox(height: Space.s3),
                              week
                                  ? HeartWeekChart(week: wk!)
                                  : HeartDayChart(day: day!),
                              const SizedBox(height: Space.s3),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: Space.s4,
                                runSpacing: Space.s2,
                                children: [
                                  for (final z in Zone.values)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ExcludeSemantics(
                                          child: Text(
                                            '•••',
                                            style: TextStyle(
                                              color: zoneColor(c, z),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          zoneLabel[z]!,
                                          style: TextStyle(
                                            color: c.mutedFg,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (zones != null) ...[
          const SizedBox(height: Space.s4),
          ZoneList(secs: zones),
        ],
      ],
    );
  }
}

class ZoneList extends StatelessWidget {
  const ZoneList({super.key, required this.secs});
  final Map<Zone, double> secs;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = secs.values.fold(0.0, (a, b) => a + b);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Time in heart-rate zones'),
          const SizedBox(height: Space.s1),
          const Muted('Zones are set from your fitness and age.'),
          const SizedBox(height: Space.s4),
          for (final z in Zone.values.reversed) ...[
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: zoneLabel[z],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text:
                              ' · ${total == 0 ? 0 : (secs[z]! / total * 100).round()}% · ${fromSeconds(secs[z]!)}',
                          style: TextStyle(color: c.mutedFg),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 14,
                      color: c.track,
                      alignment: Alignment.centerLeft,
                      child: DrawIn(
                        builder: (_, t) {
                          final f = total == 0 ? 0.0 : secs[z]! / total;
                          return FractionallySizedBox(
                            widthFactor:
                                (secs[z]! > 0 ? (f < 0.015 ? 0.015 : f) : 0) *
                                t,
                            child: Container(
                              decoration: BoxDecoration(
                                color: zoneColor(c, z),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s4),
          ],
        ],
      ),
    );
  }
}

// ---------------- Sleep ----------------
class SleepTab extends StatelessWidget {
  const SleepTab({super.key, required this.theme});
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), h = s.health;
    if (h == null) return TabPage(children: _loading('Sleep', theme));
    final c = context.c;
    return TabPage(
      onRefresh: s.reload,
      children: [
        TabHeader(title: 'Sleep', theme: theme),
        SleepDetail(h: h),
        SleepSummaryCard(h: h, full: true),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('About sleep stages'),
              const SizedBox(height: Space.s3),
              for (final (name, text, color) in [
                ('Deep', 'sleep helps your body recover.', c.sDeep),
                ('Light', 'sleep is most of the night.', c.sLight),
                ('REM', 'sleep is when you dream and helps memory.', c.sRem),
                ('Awake', 'short wake-ups are normal.', c.sAwake),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' $text'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (h.spo2 != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle('Overnight blood oxygen'),
                const SizedBox(height: Space.s2),
                Text('${h.spo2!.avg}%', style: mono(context, size: 26)),
                Muted(
                  'Ranged from ${h.spo2!.low}% to ${h.spo2!.high}% last night.',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SleepDetail extends StatefulWidget {
  const SleepDetail({super.key, required this.h});
  final Health h;
  @override
  State<SleepDetail> createState() => _SleepDetailState();
}

class _SleepDetailState extends State<SleepDetail> {
  int? _i;
  @override
  Widget build(BuildContext context) {
    final nights = widget.h.sleep
        .where((n) => !n.isNap && n.stages.isNotEmpty)
        .toList();
    if (nights.isEmpty) return const SizedBox.shrink();
    final i = (_i ?? nights.length - 1).clamp(0, nights.length - 1);
    final n = nights[i];
    final c = context.c;
    final tags = {
      QStatus.ok: ('In range', c.up, c.upBg),
      QStatus.high: ('Above range', c.warn, c.warnBg),
      QStatus.low: ('Below range', c.warn, c.warnBg),
      QStatus.none: ('No data', c.mutedFg, c.track),
    };
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      child: Column(
                        key: ValueKey(i),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i == nights.length - 1
                                ? 'Last night'
                                : longDate(n.end),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Muted(
                            '${dur(n.minutes)} asleep · ${dur(n.end.difference(n.start).inMinutes)} in bed',
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconBtn(
                    icon: LucideIcons.chevronLeft,
                    label: 'Earlier night',
                    onTap: i <= 0 ? null : () => setState(() => _i = i - 1),
                  ),
                  const SizedBox(width: Space.s2),
                  IconBtn(
                    icon: LucideIcons.chevronRight,
                    label: 'Later night',
                    onTap: i >= nights.length - 1
                        ? null
                        : () => setState(() => _i = i + 1),
                  ),
                ],
              ),
              const SizedBox(height: Space.s4),
              AnimatedSwitcher(
                duration: Motion.slow,
                child: KeyedSubtree(
                  key: ValueKey(i),
                  child: Hypnogram(night: n),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s4),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Sleep quality'),
              const SizedBox(height: Space.s4),
              for (final q in sleepQuality(n)) ...[
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: q.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' · ${q.value}',
                                    style: TextStyle(color: c.mutedFg),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: Space.s2),
                          Pill(
                            tags[q.status]!.$1,
                            fg: tags[q.status]!.$2,
                            bg: tags[q.status]!.$3,
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.s2),
                      QualityBar(
                        key: ValueKey('$i-${q.label}'),
                        pos: q.pos,
                        bandFrom: q.bandFrom,
                        bandTo: q.bandTo,
                        color: q.status == QStatus.ok
                            ? c.up
                            : q.status == QStatus.none
                            ? Colors.transparent
                            : c.warn,
                      ),
                      const SizedBox(height: Space.s2),
                      Muted(q.why, size: 12),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s4),
              ],
              const Muted(
                'The dashed box is the typical range. These are simple, open rules worked out from your sleep stages. Google\'s own sleep score uses a private formula that it does not share.',
                size: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Activity ----------------
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key, required this.theme, required this.goTo});
  final ThemeController theme;
  final void Function(int) goTo;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context), h = s.health;
    if (h == null) return TabPage(children: _loading('Activity', theme));
    return TabPage(
      onRefresh: s.reload,
      children: [
        TabHeader(title: 'Activity', theme: theme),
        StepsCard(h: h),
        HourlyCard(h: h),
        WeekSteps(h: h),
        AzmCard(h: h),
        if (h.hourly.length > 1)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle(
                  'Heart rate during the day',
                  icon: LucideIcons.heartPulse,
                ),
                const SizedBox(height: Space.s3),
                RangeChart(points: h.hourly, height: 130),
                const SizedBox(height: Space.s2),
                Pressable(
                  onTap: () => goTo(1),
                  semanticLabel: 'Heart details',
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Text(
                          'Heart details',
                          style: TextStyle(color: context.c.link, fontSize: 14),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: context.c.link,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Animated segmented control with a sliding thumb.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final List<(T, String, IconData?)> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final idx = options.indexWhere((o) => o.$1 == value);
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                left: w * idx,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: c.shadow,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (v, label, icon) in options)
                    Expanded(
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        selected: v == value,
                        button: true,
                        label: label,
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onChanged(v),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.base,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 15,
                                fontWeight: v == value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: v == value ? c.fg : c.mutedFg,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (icon != null) ...[
                                    Icon(
                                      icon,
                                      size: 18,
                                      color: v == value ? c.fg : c.mutedFg,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(label),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
