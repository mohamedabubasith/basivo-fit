import 'format.dart';
import 'models.dart';

enum QStatus { ok, high, low, none }

class QualityRow {
  const QualityRow(this.label, this.value, this.status, this.pos, this.bandFrom, this.bandTo, this.why);
  final String label, value, why;
  final QStatus status;
  final double pos, bandFrom, bandTo;
}

double _sum(Iterable<Span> a) => a.fold(0.0, (x, r) => x + r.minutes);

/// Simple, open rules worked out from the sleep stages (not Google's private formula).
List<QualityRow> sleepQuality(SleepNight n) {
  final st = [...n.stages]..sort((a, b) => a.start.compareTo(b.start));
  final firstSound = st.where((x) => x.stage == Stage.deep || x.stage == Stage.rem).firstOrNull;
  final toSound = firstSound?.start.difference(n.start).inMinutes;
  final sound = _sum(st.where((x) => x.stage == Stage.deep || x.stage == Stage.rem));
  final soundPct = n.minutes > 0 ? sound / n.minutes * 100 : 0.0;
  final restless = _sum(n.restless.where((r) => !r.start.isBefore(n.start) && !r.end.isAfter(n.end))).round();
  final breaks = st.where((x) => x.stage == Stage.awake && x.minutes >= 5 && x.start.isAfter(n.start) && x.end.isBefore(n.end)).toList();
  final breakMin = _sum(breaks).round();
  double clamp(double v) => v.clamp(0, 1).toDouble();
  return [
    QualityRow('Time to deep or REM sleep', toSound == null ? '--' : dur(toSound), toSound == null ? QStatus.none : toSound <= 30 ? QStatus.ok : QStatus.high,
        clamp((toSound ?? 0) / 90), 0, 30 / 90, 'How long after going to bed you first reached deep or REM sleep. Under 30 minutes is typical.'),
    QualityRow('Deep + REM sleep', '${dur(sound)} (${soundPct.round()}%)', soundPct >= 35 ? QStatus.ok : QStatus.low, clamp(soundPct / 70), 35 / 70, 55 / 70,
        'The restoring part of sleep. Adults usually spend 35 to 55% of sleep in deep and REM.'),
    QualityRow('Restlessness', dur(restless), restless <= 15 ? QStatus.ok : QStatus.high, clamp(restless / 60), 0, 15 / 60,
        'Short wake-ups and tossing that you probably do not remember. Under 15 minutes is typical.'),
    QualityRow('Interruptions', '${dur(breakMin)}, ${breaks.length} ${breaks.length == 1 ? 'time' : 'times'}', breakMin <= 10 ? QStatus.ok : QStatus.high,
        clamp(breakMin / 60), 0, 10 / 60, 'Times you were awake for 5 minutes or more in the middle of the night. Under 10 minutes in total is typical.'),
  ];
}

/// The one-paragraph note on the Today screen.
String dailyTip(Health h) {
  final night = h.mainSleep;
  final left = (h.stepGoal - h.stepsToday).clamp(0, 1 << 30);
  final parts = <String>[];
  if (night != null) parts.add('You slept ${night.minutes ~/ 60} h ${night.minutes % 60} min last night.');
  final w = night?.longestWake;
  if (w != null && w.minutes >= 20) {
    parts.add('You were awake for ${w.minutes} minutes around ${clock(w.at)}. If that happens again, get up for a short, low-light stretch, then go back to bed.');
  }
  parts.add(left > 0 ? '${num0(left)} more steps reach your goal, about ${(left / 110).round().clamp(5, 1 << 30)} minutes of walking.' : 'You reached your step goal today.');
  final low = h.devices.where((d) => d.battery != null && d.battery! <= 20).firstOrNull;
  if (low != null) parts.add('Charge your ${low.name} soon, it is at ${low.battery}%.');
  return parts.join(' ');
}
