import 'dart:math' as math;
import 'models.dart';

/// Demo data with made-up but realistic numbers, used by "Try the demo" and the tests.
Health demoHealth([DateTime? clock]) {
  final now = clock ?? DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  DateTime day(int back) => midnight.subtract(Duration(days: back));
  const avgs = [71, 64, 66, 65, 62, 63, 60, 62, 61, 66, 67, 70, 86, 92, 95, 90, 84];
  const steps = [0, 0, 0, 0, 0, 0, 60, 210, 120, 260, 410, 190, 30, 140, 280, 90, 120];
  const nights = [
    [402, 70, 232, 82, 20], [371, 60, 216, 72, 24], [441, 86, 249, 90, 17], [388, 64, 230, 76, 19],
    [425, 78, 246, 84, 18], [350, 52, 210, 64, 26], [409, 68, 228, 63, 50],
  ];
  return Health(
    live: false,
    updatedAt: now,
    devices: [Device(name: 'Fitbit Charge', type: 'TRACKER', battery: 71, batteryStatus: 'Medium', lastSync: now.subtract(const Duration(minutes: 6)))],
    now: HeartNow(76, now.subtract(const Duration(minutes: 4))),
    hourly: [for (var i = 0; i < avgs.length; i++) HeartHour(midnight.add(Duration(hours: i)), avgs[i], avgs[i] - 9, avgs[i] + 20)],
    resting: [for (var i = 0; i < 7; i++) DayValue(day(6 - i), const [64, 63, 66, 62, 61, 63, 62][i])],
    hrv: [for (var i = 0; i < 7; i++) DayValue(day(6 - i), const [31.2, 30.4, 28.9, 30.8, 32.1, 29.6, 30.9][i])],
    todayRange: _rangeOf(demoHeartDay(0, now)),
    stepsToday: 6480,
    stepsWeek: [for (var i = 0; i < 7; i++) DayValue(day(6 - i), const [7210, 9420, 5310, 8650, 10120, 6890, 6480][i])],
    distanceKm: 4.8,
    activeKcal: 326,
    totalKcal: 1890,
    azm: const Azm(fatBurn: 19, cardio: 7),
    hourSteps: [for (var i = 0; i < steps.length; i++) DayValue(midnight.add(Duration(hours: i)), steps[i])],
    hourlyDone: 3,
    exerciseDays: 2,
    sleep: [for (var i = 0; i < 7; i++) _night(day(6 - i), nights[i], i == 6)],
    spo2: (avg: 96.8, low: 95.0, high: 98.1),
    respRate: 14.8,
    skinTempC: 33.6,
    weightKg: 71,
  );
}

({int min, int max, int avg})? _rangeOf(HeartDay d) {
  if (d.points.isEmpty) return null;
  return (min: d.min!, max: d.max!, avg: (d.points.fold(0.0, (a, p) => a + p.avg) / d.points.length).round());
}

// About 90-minute cycles of light, deep, light and REM sleep, with one long wake-up on the last night.
SleepNight _night(DateTime morning, List<int> v, bool longWake) {
  final start = morning.subtract(const Duration(hours: 1)).add(const Duration(minutes: 22)); // 11:22 PM the evening before
  final plan = <(Stage, int)>[
    (Stage.awake, 3), (Stage.light, 14), (Stage.deep, 16), (Stage.light, 12), (Stage.rem, 10), (Stage.light, 16), (Stage.deep, 14),
    (Stage.awake, 4), (Stage.light, 22), (Stage.rem, 14), (Stage.awake, longWake ? 38 : 6), (Stage.light, 28), (Stage.deep, 12),
    (Stage.light, 24), (Stage.rem, 22), (Stage.light, 30), (Stage.deep, 10), (Stage.light, 26), (Stage.rem, 20), (Stage.awake, 8),
    (Stage.light, 40), (Stage.rem, 18), (Stage.light, 24),
  ];
  var t = start;
  final stages = <StageSpan>[];
  for (final (s, m) in plan) {
    final e = t.add(Duration(minutes: m));
    stages.add(StageSpan(s, t, e));
    t = e;
  }
  final rnd = math.Random(morning.day);
  final restless = [for (final m in [21, 36, 58, 97, 102, 166, 214, 281, 318, 412, 447]) Span(start.add(Duration(minutes: m + rnd.nextInt(4))), start.add(Duration(minutes: m + 2 + rnd.nextInt(4))))];
  double tot(Stage k) => stages.where((x) => x.stage == k).fold(0.0, (a, x) => a + x.minutes);
  final asleep = (tot(Stage.deep) + tot(Stage.light) + tot(Stage.rem)).round();
  return SleepNight(
    date: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][morning.weekday - 1],
    minutes: asleep,
    deep: tot(Stage.deep).round(),
    light: tot(Stage.light).round(),
    rem: tot(Stage.rem).round(),
    awake: tot(Stage.awake).round(),
    start: start,
    end: t,
    nap: false,
    longestWake: longWake ? (minutes: 38, at: start.add(const Duration(minutes: 197))) : null,
    stages: stages,
    restless: restless,
  );
}

HeartDay demoHeartDay(int offset, [DateTime? clock]) {
  final now = clock ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
  final end = start.add(const Duration(days: 1));
  final stop = offset == 0 ? now : end;
  final pts = <HrPoint>[];
  for (var t = start; t.isBefore(stop); t = t.add(const Duration(minutes: 5))) {
    final h = t.difference(start).inMinutes / 60;
    final base = h < 7 ? 61 : h < 11 ? 66 : h < 12.5 ? 96 : h < 18 ? 83 : 75;
    final v = base + math.sin(t.millisecondsSinceEpoch / 900000) * 4 + (t.minute % 35) / 5 - 3 + ((h - 11.6).abs() < 0.15 ? 22 : 0);
    pts.add(HrPoint(t, v, v - 5, v + 6));
  }
  return HeartDay(start: start, end: end, points: pts, limits: ZoneLimits.fallback,
      zoneSeconds: {Zone.light: 80640, Zone.moderate: 1260, Zone.vigorous: 0, Zone.peak: 0});
}

HeartWeek demoHeartWeek([DateTime? clock]) {
  final now = clock ?? DateTime.now();
  final m = DateTime(now.year, now.month, now.day);
  return HeartWeek(
    days: [for (var i = 0; i < 7; i++) HeartWeekDay(m.subtract(Duration(days: 6 - i)), 53 + i % 3, 110 + (i * 7) % 24, 71 + i % 4)],
    limits: ZoneLimits.fallback,
    zoneSeconds: {Zone.light: 556000, Zone.moderate: 6600, Zone.vigorous: 840, Zone.peak: 0},
  );
}
