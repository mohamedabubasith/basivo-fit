enum Stage { awake, light, deep, rem }

class Span {
  const Span(this.start, this.end);
  final DateTime start, end;
  double get minutes => end.difference(start).inSeconds / 60;
}

class StageSpan extends Span {
  const StageSpan(this.stage, super.start, super.end);
  final Stage stage;
}

class SleepNight {
  const SleepNight({
    required this.date,
    required this.minutes,
    required this.deep,
    required this.light,
    required this.rem,
    required this.awake,
    required this.start,
    required this.end,
    this.nap,
    this.longestWake,
    this.stages = const [],
    this.restless = const [],
  });
  final String date;
  final int minutes, deep, light, rem, awake;
  final DateTime start, end;
  final bool? nap;
  final ({int minutes, DateTime at})? longestWake;
  final List<StageSpan> stages;
  final List<Span> restless;

  bool get isNap => nap ?? minutes < 180;
}

class Device {
  const Device({required this.name, required this.type, this.battery, this.batteryStatus = '', this.lastSync});
  final String name, type, batteryStatus;
  final int? battery;
  final DateTime? lastSync;
}

class HeartHour {
  const HeartHour(this.at, this.avg, this.min, this.max);
  final DateTime at;
  final int avg, min, max;
}

class HeartNow {
  const HeartNow(this.bpm, this.at);
  final int bpm;
  final DateTime at;
}

class DayValue<T> {
  const DayValue(this.date, this.value);
  final DateTime date;
  final T value;
}

class Azm {
  const Azm({this.fatBurn = 0, this.cardio = 0, this.peak = 0});
  final int fatBurn, cardio, peak;
  int get total => fatBurn + 2 * (cardio + peak);
}

class Health {
  const Health({
    required this.live,
    required this.updatedAt,
    required this.devices,
    this.stepGoal = 8000,
    this.now,
    this.hourly = const [],
    this.resting = const [],
    this.hrv = const [],
    this.todayRange,
    this.stepsToday = 0,
    this.stepsWeek = const [],
    this.distanceKm = 0,
    this.activeKcal = 0,
    this.totalKcal,
    this.azm = const Azm(),
    this.hourSteps = const [],
    this.hourlyDone = 0,
    this.exerciseDays = 0,
    this.sleep = const [],
    this.spo2,
    this.respRate,
    this.skinTempC,
    this.weightKg,
  });

  final bool live;
  final DateTime updatedAt;
  final int stepGoal;
  final List<Device> devices;
  final HeartNow? now;
  final List<HeartHour> hourly;
  final List<DayValue<int>> resting;
  final List<DayValue<double>> hrv;
  final ({int min, int max, int avg})? todayRange;
  final int stepsToday;
  final List<DayValue<int>> stepsWeek;
  final double distanceKm;
  final int activeKcal;
  final int? totalKcal;
  final Azm azm;
  final List<DayValue<int>> hourSteps;
  final int hourlyDone;
  static const hourlyGoal = 9;
  final int exerciseDays;
  static const exerciseGoal = 5;
  final List<SleepNight> sleep;
  final ({double avg, double low, double high})? spo2;
  final double? respRate, skinTempC, weightKg;

  Health withNow(HeartNow n) => Health(
        live: live, updatedAt: updatedAt, devices: devices, stepGoal: stepGoal, now: n, hourly: hourly, resting: resting,
        hrv: hrv, todayRange: todayRange, stepsToday: stepsToday, stepsWeek: stepsWeek, distanceKm: distanceKm,
        activeKcal: activeKcal, totalKcal: totalKcal, azm: azm, hourSteps: hourSteps, hourlyDone: hourlyDone,
        exerciseDays: exerciseDays, sleep: sleep, spo2: spo2, respRate: respRate, skinTempC: skinTempC, weightKg: weightKg,
      );

  SleepNight? get mainSleep {
    for (final n in sleep.reversed) {
      if (!n.isNap) return n;
    }
    return sleep.isEmpty ? null : sleep.last;
  }
}

// ---------- Heart detail ----------
enum Zone { light, moderate, vigorous, peak }

const zoneLabel = {Zone.light: 'Light', Zone.moderate: 'Moderate', Zone.vigorous: 'Vigorous', Zone.peak: 'Peak'};

class ZoneLimits {
  const ZoneLimits(this.moderate, this.vigorous, this.peak);
  final int moderate, vigorous, peak;
  static const fallback = ZoneLimits(116, 142, 174);
  Zone zoneOf(num bpm) => bpm >= peak ? Zone.peak : bpm >= vigorous ? Zone.vigorous : bpm >= moderate ? Zone.moderate : Zone.light;
}

class HrPoint {
  const HrPoint(this.t, this.avg, this.min, this.max);
  final DateTime t;
  final double avg, min, max;
}

class HeartDay {
  const HeartDay({required this.start, required this.end, required this.points, required this.limits, required this.zoneSeconds});
  final DateTime start, end;
  final List<HrPoint> points;
  final ZoneLimits limits;
  final Map<Zone, double> zoneSeconds;
  // Smoothed 5-minute averages, like the Google Health app.
  int? get min => points.isEmpty ? null : points.map((p) => p.avg).reduce((a, b) => a < b ? a : b).round();
  int? get max => points.isEmpty ? null : points.map((p) => p.avg).reduce((a, b) => a > b ? a : b).round();
}

class HeartWeekDay {
  const HeartWeekDay(this.date, this.min, this.max, this.avg);
  final DateTime date;
  final int min, max, avg;
}

class HeartWeek {
  const HeartWeek({required this.days, required this.limits, required this.zoneSeconds});
  final List<HeartWeekDay> days;
  final ZoneLimits limits;
  final Map<Zone, double> zoneSeconds;
}
