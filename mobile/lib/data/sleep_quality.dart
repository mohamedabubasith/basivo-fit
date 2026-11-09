import 'format.dart';
import 'models.dart';

enum QStatus { ok, high, low, none }

class QualityRow {
  const QualityRow(
    this.label,
    this.value,
    this.status,
    this.pos,
    this.bandFrom,
    this.bandTo,
    this.why,
  );
  final String label, value, why;
  final QStatus status;
  final double pos, bandFrom, bandTo;
}

double _sum(Iterable<Span> a) => a.fold(0.0, (x, r) => x + r.minutes);

/// Simple, open rules worked out from the sleep stages (not Google's private formula).
List<QualityRow> sleepQuality(SleepNight n) {
  final st = [...n.stages]..sort((a, b) => a.start.compareTo(b.start));
  final firstSound = st
      .where((x) => x.stage == Stage.deep || x.stage == Stage.rem)
      .firstOrNull;
  final toSound = firstSound?.start.difference(n.start).inMinutes;
  final sound = _sum(
    st.where((x) => x.stage == Stage.deep || x.stage == Stage.rem),
  );
  final soundPct = n.minutes > 0 ? sound / n.minutes * 100 : 0.0;
  final restless = _sum(
    n.restless.where(
      (r) => !r.start.isBefore(n.start) && !r.end.isAfter(n.end),
    ),
  ).round();
  final breaks = st
      .where(
        (x) =>
            x.stage == Stage.awake &&
            x.minutes >= 5 &&
            x.start.isAfter(n.start) &&
            x.end.isBefore(n.end),
      )
      .toList();
  final breakMin = _sum(breaks).round();
  double clamp(double v) => v.clamp(0, 1).toDouble();
  return [
    QualityRow(
      'Time to deep or REM sleep',
      toSound == null ? '--' : dur(toSound),
      toSound == null
          ? QStatus.none
          : toSound <= 30
          ? QStatus.ok
          : QStatus.high,
      clamp((toSound ?? 0) / 90),
      0,
      30 / 90,
      'How long after going to bed you first reached deep or REM sleep. Under 30 minutes is typical.',
    ),
    QualityRow(
      'Deep + REM sleep',
      '${dur(sound)} (${soundPct.round()}%)',
      soundPct >= 35 ? QStatus.ok : QStatus.low,
      clamp(soundPct / 70),
      35 / 70,
      55 / 70,
      'The restoring part of sleep. Adults usually spend 35 to 55% of sleep in deep and REM.',
    ),
    QualityRow(
      'Restlessness',
      dur(restless),
      restless <= 15 ? QStatus.ok : QStatus.high,
      clamp(restless / 60),
      0,
      15 / 60,
      'Short wake-ups and tossing that you probably do not remember. Under 15 minutes is typical.',
    ),
    QualityRow(
      'Interruptions',
      '${dur(breakMin)}, ${breaks.length} ${breaks.length == 1 ? 'time' : 'times'}',
      breakMin <= 10 ? QStatus.ok : QStatus.high,
      clamp(breakMin / 60),
      0,
      10 / 60,
      'Times you were awake for 5 minutes or more in the middle of the night. Under 10 minutes in total is typical.',
    ),
  ];
}

/// The one-paragraph note on the Today screen.
String dailyTip(Health h) {
  final night = h.mainSleep;
  final left = (h.stepGoal - h.stepsToday).clamp(0, 1 << 30);
  final parts = <String>[];
  if (night != null) {
    parts.add(
      'You slept ${night.minutes ~/ 60} h ${night.minutes % 60} min last night.',
    );
  }
  final w = night?.longestWake;
  if (w != null && w.minutes >= 20) {
    parts.add(
      'You were awake for ${w.minutes} minutes around ${clock(w.at)}. If that happens again, get up for a short, low-light stretch, then go back to bed.',
    );
  }
  parts.add(
    left > 0
        ? '${num0(left)} more steps reach your goal, about ${(left / 110).round().clamp(5, 1 << 30)} minutes of walking.'
        : 'You reached your step goal today.',
  );
  final low = h.devices
      .where((d) => d.battery != null && d.battery! <= 20)
      .firstOrNull;
  if (low != null) {
    parts.add('Charge your ${low.name} soon, it is at ${low.battery}%.');
  }
  return parts.join(' ');
}

// ---------------- Easy sleep view ----------------

/// Typical share of sleep for adults (approximate, widely cited ranges).
enum Level { low, typical, high }

class StageStat {
  const StageStat(
    this.stage,
    this.name,
    this.minutes,
    this.pct,
    this.from,
    this.to,
    this.level,
    this.meaning,
  );
  final Stage stage;
  final String name, meaning;
  final int minutes;
  final double pct, from, to;
  final Level level;
}

/// Each stage as minutes, share of the night, typical range and a plain meaning.
/// Deep, light and REM are shares of sleep; awake is a share of time in bed.
List<StageStat> stageStats(SleepNight n) {
  final asleep = n.minutes <= 0 ? 1 : n.minutes;
  final inBed = n.minutes + n.awake <= 0 ? 1 : n.minutes + n.awake;
  StageStat s(
    Stage st,
    String name,
    int m,
    int of,
    double from,
    double to,
    String meaning,
  ) {
    final pct = m / of * 100;
    final level = pct < from
        ? Level.low
        : (pct > to ? Level.high : Level.typical);
    return StageStat(st, name, m, pct, from, to, level, meaning);
  }

  return [
    s(Stage.deep, 'Deep', n.deep, asleep, 13, 23, 'Body recovery and repair.'),
    s(Stage.rem, 'REM', n.rem, asleep, 20, 25, 'Dreaming, memory and mood.'),
    s(
      Stage.light,
      'Light',
      n.light,
      asleep,
      45,
      60,
      'Most of the night. Links the other stages.',
    ),
    s(
      Stage.awake,
      'Awake',
      n.awake,
      inBed,
      0,
      10,
      'Short wake-ups are normal.',
    ),
  ];
}

/// One short, plain sentence about the night.
String sleepVerdict(SleepNight n) {
  final h = n.minutes / 60;
  final length = h < 6
      ? 'Short night'
      : h < 7
      ? 'A little short'
      : h <= 9
      ? 'Good length'
      : 'Long night';
  final st = {for (final x in stageStats(n)) x.stage: x};
  final good = <String>[], low = <String>[];
  for (final k in [Stage.deep, Stage.rem]) {
    final x = st[k]!;
    (x.level == Level.low ? low : good).add(
      x.name == 'REM' ? 'REM' : 'deep sleep',
    );
  }
  final awake = st[Stage.awake]!;
  final parts = <String>['$length.'];
  if (good.isNotEmpty && low.isEmpty) {
    parts.add('You got enough ${good.join(' and ')}.');
  } else if (good.isNotEmpty) {
    parts.add(
      '${_cap(good.join(' and '))} was good, but ${low.join(' and ')} was low.',
    );
  } else {
    parts.add('Deep sleep and REM were both low.');
  }
  if (awake.level == Level.high) parts.add('You were awake quite a bit.');
  if (h < 7) parts.add('Aim for 7 hours or more.');
  return parts.join(' ');
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class SleepCheck {
  const SleepCheck(this.ok, this.title, this.detail);
  final bool ok;
  final String title, detail;
}

/// Three simple checks, phrased as outcomes instead of gauges.
List<SleepCheck> sleepChecks(SleepNight n) {
  final rows = sleepQuality(n);
  final toSound = rows[0], restless = rows[2], breaks = rows[3];
  return [
    SleepCheck(
      toSound.status != QStatus.high,
      toSound.status == QStatus.none
          ? 'No deep or REM sleep recorded'
          : 'Reached deep sleep in ${toSound.value}',
      'Under 30 minutes is typical.',
    ),
    SleepCheck(
      breaks.status == QStatus.ok,
      breaks.value.startsWith('0 min')
          ? 'No long wake-ups'
          : 'Woke up for ${breaks.value}',
      'Wake-ups of 5 minutes or more. Under 10 minutes in total is typical.',
    ),
    SleepCheck(
      restless.status == QStatus.ok,
      'Restless for ${restless.value}',
      'Tossing and turning you probably do not remember. Under 15 minutes is typical.',
    ),
  ];
}
