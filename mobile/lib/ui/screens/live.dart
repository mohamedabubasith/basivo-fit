import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/heart_sensor.dart';
import '../../data/models.dart';
import '../../state/live_heart.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../charts/charts.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/pulse.dart';

/// Live heart rate over Bluetooth: find a sensor, connect, and watch every beat.
class LiveHeartCard extends StatelessWidget {
  const LiveHeartCard({super.key, this.limits = ZoneLimits.fallback});
  final ZoneLimits limits;

  @override
  Widget build(BuildContext context) {
    final live = LiveScope.of(context), c = context.c;
    final body = switch (live.phase) {
      LivePhase.live => _Live(live: live, limits: limits),
      LivePhase.scanning => _Scanning(live: live),
      LivePhase.connecting => _Busy(
        text: 'Connecting to ${live.device?.name ?? 'sensor'}…',
        onCancel: () => live.stop(),
      ),
      LivePhase.lost => _Busy(
        text:
            'Connection to ${live.device?.name ?? 'the sensor'} lost. Reconnecting…',
        onCancel: () => live.stop(),
      ),
      LivePhase.needsPermission => _Message(
        icon: LucideIcons.bluetoothOff,
        text:
            'Basivo Fit needs Bluetooth permission to find heart rate sensors near you.',
        actions: [
          AppButton(
            label: 'Allow Bluetooth',
            kind: BtnKind.primary,
            onTap: live.startScan,
          ),
          AppButton(label: 'Open settings', onTap: openAppSettings),
        ],
      ),
      LivePhase.bluetoothOff => _Message(
        icon: LucideIcons.bluetoothOff,
        text:
            'Bluetooth is off. Turn it on in your phone settings, then try again.',
        actions: [
          AppButton(
            label: 'Try again',
            kind: BtnKind.primary,
            onTap: live.startScan,
          ),
        ],
      ),
      LivePhase.locationOff => _Message(
        icon: LucideIcons.bluetoothOff,
        text:
            'On this Android version, finding Bluetooth devices needs Location turned on. Turn it on, then try again.',
        actions: [
          AppButton(
            label: 'Try again',
            kind: BtnKind.primary,
            onTap: live.startScan,
          ),
        ],
      ),
      LivePhase.unsupported => const _Message(
        icon: LucideIcons.bluetoothOff,
        text:
            'Bluetooth heart rate works in the Android and iPhone app. On the web, use the demo.',
        actions: [],
      ),
      LivePhase.notSharing => _Message(
        icon: LucideIcons.heartOff,
        text:
            '${live.device?.name ?? 'This device'} is nearby but is not sharing heart rate yet.\n\n${sharingSteps(live.device?.name)}\n\nThen tap Try again.',
        actions: [
          AppButton(
            label: 'Try again',
            kind: BtnKind.primary,
            onTap: live.startScan,
          ),
        ],
      ),
      LivePhase.failed => _Message(
        icon: LucideIcons.bluetoothOff,
        text:
            'Could not get heart rate from ${live.device?.name ?? 'the sensor'}. Check these, then try again:\n\n'
            '1. Heart rate sharing is on. ${sharingSteps(live.device?.name)}\n'
            '2. You are wearing it. A band on its charger does not measure or share heart rate.\n'
            '3. You did not pair it in Android Bluetooth settings. If it shows there as "Pairing" or paired, tap it and choose Forget. Basivo Fit connects to it directly.\n'
            '4. It is close to your phone, and no other app such as Zwift or Peloton is connected to it.\n\n'
            'Tap Try again to pick a different device from the list.',
        actions: [
          AppButton(
            label: 'Try again',
            kind: BtnKind.primary,
            onTap: live.startScan,
          ),
          AppButton(
            label: 'Reset pairing and try again',
            icon: LucideIcons.rotateCcw,
            onTap: live.resetPairing,
          ),
        ],
      ),
      LivePhase.idle => _Idle(live: live),
    };
    return AppCard(
      gradient: live.phase == LivePhase.live
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.6],
              colors: [c.secondary.withValues(alpha: 0.16), c.card],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            'Live over Bluetooth',
            icon: live.phase == LivePhase.live
                ? LucideIcons.bluetoothConnected
                : LucideIcons.bluetooth,
            trailing: live.phase == LivePhase.live
                ? const LiveBadge(live: true, text: 'every beat')
                : null,
          ),
          const SizedBox(height: Space.s3),
          AnimatedSize(
            duration: Motion.slow,
            curve: Motion.ease,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Motion.base,
              child: KeyedSubtree(key: ValueKey(live.phase), child: body),
            ),
          ),
          if (live.phase != LivePhase.live && !live.demoMode)
            _Details(expanded: live.phase == LivePhase.failed),
        ],
      ),
    );
  }
}

/// Step-by-step Bluetooth log, so a failed connection can be shared as a screenshot.
class _Details extends StatelessWidget {
  const _Details({required this.expanded});
  final bool expanded;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<String>>(
    valueListenable: bleLog,
    builder: (context, lines, _) {
      if (lines.isEmpty) return const SizedBox.shrink();
      final c = context.c;
      return Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: expanded,
            tilePadding: EdgeInsets.zero,
            iconColor: c.mutedFg,
            collapsedIconColor: c.mutedFg,
            leading: Icon(LucideIcons.terminal, size: 18, color: c.mutedFg),
            title: Text(
              'Connection details',
              style: TextStyle(fontSize: 14, color: c.fg),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(
                  color: c.muted,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: c.border),
                ),
                child: SelectableText(
                  lines
                      .skip(lines.length > 14 ? lines.length - 14 : 0)
                      .join('\n'),
                  style: mono(context, size: 11, color: c.mutedFg),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// How to turn on heart rate sharing for the device the user picked.
String sharingSteps(String? name) {
  final n = (name ?? '').toLowerCase();
  if (RegExp(r'fitbit|\bair\b|charge|inspire|versa|sense|pixel').hasMatch(n)) {
    return _fitbitSteps;
  }
  if (RegExp(r'amazfit|t-rex|gtr|gts|bip|zepp|balance|cheetah').hasMatch(n)) {
    return 'On an Amazfit watch: turn on Heart rate sharing (also called "Share heart rate" or "Discoverable") in the watch settings or in the Zepp app.';
  }
  return 'Turn on heart rate broadcast on the device (it may be called "Share heart rate" or "Broadcast heart rate").';
}

const _fitbitSteps =
    'On a Fitbit Air or Charge 6: open the Google Health app, go to Connections, tap your Fitbit, then turn on Share heart rate (and Always visible if you see it).';

class _Idle extends StatelessWidget {
  const _Idle({required this.live});
  final LiveHeart live;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Muted(
        'See your heart rate every second from a chest strap or a watch that broadcasts heart rate.',
      ),
      const SizedBox(height: Space.s3),
      AppButton(
        label: 'Find a sensor',
        icon: LucideIcons.bluetoothSearching,
        kind: BtnKind.primary,
        onTap: live.startScan,
      ),
      const SizedBox(height: Space.s2),
      const _Help(),
    ],
  );
}

class _Help extends StatelessWidget {
  const _Help();
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Space.s2),
        iconColor: context.c.mutedFg,
        collapsedIconColor: context.c.mutedFg,
        leading: Icon(
          LucideIcons.circleHelp,
          size: 18,
          color: context.c.mutedFg,
        ),
        title: Text(
          'Which devices work?',
          style: TextStyle(fontSize: 14, color: context.c.fg),
        ),
        children: [
          const Muted(
            'Any device that sends heart rate in the standard Bluetooth format works: most chest straps and arm bands, and watches with a "broadcast heart rate" or "share heart rate" setting.\n\n'
            '$_fitbitSteps Keep the band near your phone, then tap Find a sensor.\n\n'
            'Do not pair it in Android Bluetooth settings. Basivo Fit connects to it directly, and a pairing there can get stuck on "Pairing".',
            size: 13,
          ),
        ],
      ),
    ),
  );
}

class _Scanning extends StatelessWidget {
  const _Scanning({required this.live});
  final LiveHeart live;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Radar(),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  live.found.isEmpty
                      ? 'Looking for heart rate sensors…'
                      : 'Tap a sensor to connect',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s3),
        for (var i = 0; i < live.found.length; i++)
          Entrance(
            key: ValueKey(live.found[i].id),
            index: 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: Pressable(
                onTap: () => live.connect(live.found[i]),
                semanticLabel: 'Connect to ${live.found[i].name}',
                borderRadius: Radii.sm,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s3),
                  decoration: BoxDecoration(
                    color: c.muted,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          LucideIcons.heartPulse,
                          size: 20,
                          color: c.heart,
                        ),
                      ),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              live.found[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!live.found[i].advertisesHr)
                              const Muted(
                                'Turn on heart rate sharing first',
                                size: 12,
                              ),
                          ],
                        ),
                      ),
                      _SignalIcon(rssi: live.found[i].rssi),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (live.found.isEmpty) ...[
          const Muted(
            'Using a Fitbit Air or Charge 6? Turn on Share heart rate in the Google Health app first (Connections, your Fitbit, Share heart rate).',
            size: 13,
          ),
          const SizedBox(height: Space.s2),
        ],
        AppButton(
          label: 'Stop looking',
          kind: BtnKind.text,
          onTap: live.stopScan,
        ),
      ],
    );
  }
}

class _SignalIcon extends StatelessWidget {
  const _SignalIcon({this.rssi});
  final int? rssi;
  @override
  Widget build(BuildContext context) {
    final r = rssi ?? -100;
    final (icon, label) = r > -60
        ? (LucideIcons.signalHigh, 'strong')
        : r > -75
        ? (LucideIcons.signalMedium, 'good')
        : (LucideIcons.signalLow, 'weak');
    return Semantics(
      label: 'Signal $label',
      child: ExcludeSemantics(
        child: Icon(icon, size: 18, color: context.c.mutedFg),
      ),
    );
  }
}

/// Expanding rings while scanning.
class _Radar extends StatefulWidget {
  const _Radar();
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!context.reduceMotion) _c.repeat();
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
      child: SizedBox.square(
        dimension: 40,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _RadarPainter(_c.value, c.secondary),
              child: Center(
                child: Icon(
                  LucideIcons.bluetoothSearching,
                  size: 18,
                  color: c.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (final o in [0.0, 0.5]) {
      final p = (t + o) % 1;
      canvas.drawCircle(
        size.center(Offset.zero),
        8 + p * 12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter o) => o.t != t;
}

class _Busy extends StatelessWidget {
  const _Busy({required this.text, required this.onCancel});
  final String text;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.c.secondary,
            ),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.s3),
      AppButton(label: 'Cancel', onTap: onCancel),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.actions,
  });
  final IconData icon;
  final String text;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: context.c.warn)),
          const SizedBox(width: Space.s3),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
      for (final a in actions) ...[const SizedBox(height: Space.s3), a],
    ],
  );
}

class _Live extends StatelessWidget {
  const _Live({required this.live, required this.limits});
  final LiveHeart live;
  final ZoneLimits limits;
  @override
  Widget build(BuildContext context) {
    final c = context.c, r = live.latest!;
    final zone = limits.zoneOf(r.bpm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BeatingHeart(bpm: r.bpm, size: 44),
            const SizedBox(width: Space.s4),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: '${r.bpm} beats per minute, ${zoneLabel[zone]} zone',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        CountUp(
                          value: r.bpm.toDouble(),
                          duration: const Duration(milliseconds: 450),
                          builder: (_, v) => Text(
                            '${v.round()}',
                            style: mono(
                              context,
                              size: 44,
                            ).copyWith(letterSpacing: -1),
                          ),
                        ),
                        Text(
                          ' bpm',
                          style: TextStyle(fontSize: 18, color: c.mutedFg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: Motion.base,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: zoneColor(c, zone).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${zoneLabel[zone]} zone',
                            style: TextStyle(
                              color: zoneColor(c, zone),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.s2),
                        Flexible(
                          child: Text(
                            live.device?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.mutedFg, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (r.contact == false) ...[
          const SizedBox(height: Space.s3),
          Pill('Sensor is not touching your skin', fg: c.warn, bg: c.warnBg),
        ],
        const SizedBox(height: Space.s4),
        LiveChart(history: live.history, limits: limits),
        const SizedBox(height: Space.s3),
        Row(
          children: [
            _stat(
              context,
              'Lowest',
              live.sessionMin == null ? '--' : '${live.sessionMin}',
            ),
            _stat(
              context,
              'Average',
              live.sessionAvg == null ? '--' : '${live.sessionAvg}',
            ),
            _stat(
              context,
              'Highest',
              live.sessionMax == null ? '--' : '${live.sessionMax}',
            ),
            _stat(
              context,
              'HRV now',
              live.hrv == null ? '--' : '${live.hrv!.round()} ms',
            ),
          ],
        ),
        const SizedBox(height: Space.s3),
        AppButton(
          label: 'Disconnect',
          icon: LucideIcons.bluetoothOff,
          onTap: () => live.stop(forget: true),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String k, String v) => Expanded(
    child: MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(fontSize: 12, color: context.c.mutedFg)),
          const SizedBox(height: 2),
          Text(v, style: mono(context, size: 15)),
        ],
      ),
    ),
  );
}

/// The last 2 minutes, scrolling left as new beats arrive, coloured by zone.
class LiveChart extends StatelessWidget {
  const LiveChart({
    super.key,
    required this.history,
    required this.limits,
    this.height = 120,
  });
  final List<HrReading> history;
  final ZoneLimits limits;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: history.isEmpty
        ? 'Waiting for readings'
        : 'Last 2 minutes, from ${history.map((r) => r.bpm).reduce(math.min)} to ${history.map((r) => r.bpm).reduce(math.max)} bpm',
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _LivePainter(history, limits, context.c)),
        ),
      ),
    ),
  );
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.h, this.l, this.c)
    : _n = h.length,
      _last = h.isEmpty ? null : h.last.at;
  final List<HrReading> h;
  final ZoneLimits l;
  final AppColors c;
  final int _n;
  final DateTime? _last;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = c.muted,
    );
    if (h.length < 2) return;
    final now = h.last.at;
    final lo = math
        .min(h.map((r) => r.bpm).reduce(math.min) - 8, l.moderate - 30)
        .toDouble();
    final hi = math
        .max(h.map((r) => r.bpm).reduce(math.max) + 8, lo + 30)
        .toDouble();
    // Start with a 30-second window and widen to 2 minutes as readings build up.
    final window = h.last.at
        .difference(h.first.at)
        .inMilliseconds
        .clamp(30000, 120000);
    double x(DateTime t) =>
        size.width - now.difference(t).inMilliseconds / window * size.width;
    double y(num v) =>
        size.height - 8 - (v - lo) / (hi - lo) * (size.height - 16);
    for (final (v, z) in [
      (l.moderate, Zone.moderate),
      (l.vigorous, Zone.vigorous),
      (l.peak, Zone.peak),
    ]) {
      if (v > lo && v < hi) {
        final p = Paint()
          ..color = zoneColor(c, z).withValues(alpha: 0.6)
          ..strokeWidth = 1;
        for (var dx = 0.0; dx < size.width; dx += 8) {
          canvas.drawLine(Offset(dx, y(v)), Offset(dx + 2, y(v)), p);
        }
      }
    }
    final path = Path()..moveTo(x(h.first.at), y(h.first.bpm));
    for (var i = 1; i < h.length; i++) {
      final a = h[i - 1], b = h[i];
      final mx = (x(a.at) + x(b.at)) / 2;
      path.cubicTo(mx, y(a.bpm), mx, y(b.bpm), x(b.at), y(b.bpm));
    }
    final fill = Path.from(path)
      ..lineTo(x(h.last.at), size.height)
      ..lineTo(x(h.first.at), size.height)
      ..close();
    final color = zoneColor(c, l.zoneOf(h.last.bpm));
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
    );
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(x(h.last.at), y(h.last.bpm)),
      5,
      Paint()..color = c.card,
    );
    canvas.drawCircle(
      Offset(x(h.last.at), y(h.last.bpm)),
      3.5,
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivePainter o) =>
      o._n != _n || o._last != _last || o.c != c;
}
