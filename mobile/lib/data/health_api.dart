import 'dart:convert';
import 'package:http/http.dart' as http;
import 'format.dart';
import 'models.dart';

class AuthExpiredError implements Exception {
  const AuthExpiredError([this.message = 'Your sign-in has expired.']);
  final String message;
}

class PermissionError implements Exception {
  const PermissionError([this.message = 'Some permissions were not allowed.']);
  final String message;
}

class NoDeviceError implements Exception {
  const NoDeviceError([this.message = 'No Fitbit or Pixel Watch is connected to this Google account.']);
  final String message;
}

typedef J = Map<String, dynamic>;

/// Reads a user's data from the Google Health API (v4). Everything goes straight
/// from Google to this device; there is no server in between.
class HealthApi {
  HealthApi({required this.token, http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _now = clock ?? DateTime.now;

  final Future<String> Function() token;
  final http.Client _client;
  final DateTime Function() _now;

  static const _api = 'https://health.googleapis.com/v4/users/me/';
  static const _dt = '${_api}dataTypes/';

  Future<J> _call(String url, [Object? body]) async {
    final headers = {'Authorization': 'Bearer ${await token()}', if (body != null) 'Content-Type': 'application/json'};
    final uri = Uri.parse(url);
    final res = body == null ? await _client.get(uri, headers: headers) : await _client.post(uri, headers: headers, body: jsonEncode(body));
    if (res.statusCode == 401) throw const AuthExpiredError();
    if (res.statusCode == 403) throw const PermissionError();
    if (res.statusCode < 200 || res.statusCode >= 300) return {};
    final d = jsonDecode(res.body);
    return d is J ? d : {};
  }

  /// Runs a call; auth and permission problems are rethrown, anything else becomes an empty result.
  Future<J> _safe(Future<J> f) async {
    try {
      return await f;
    } on AuthExpiredError {
      rethrow;
    } on PermissionError {
      rethrow;
    } catch (_) {
      return {};
    }
  }

  static J _civ(DateTime d) => {'date': {'year': d.year, 'month': d.month, 'day': d.day}};
  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  static List<J> _pts(J x) => ((x['dataPoints'] as List?) ?? const []).whereType<J>().toList();
  static List<J> _roll(J x) => ((x['rollupDataPoints'] as List?) ?? const []).whereType<J>().toList();
  static double _n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static DateTime? _t(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
  static DateTime _civDate(J d) => DateTime((d['year'] as num).toInt(), (d['month'] as num).toInt(), (d['day'] as num).toInt());

  J _rollRange(DateTime start, DateTime end, String window) =>
      {'range': {'startTime': start.toUtc().toIso8601String(), 'endTime': end.toUtc().toIso8601String()}, 'windowSize': window};
  J _daily(DateTime start, DateTime endExclusive) => {'range': {'start': _civ(start), 'end': _civ(endExclusive)}, 'windowSizeDays': 1};

  /// Newest heart rate: 1-minute windows over the last 20 minutes, newest wins.
  Future<HeartNow?> latestHeartRate() async {
    final now = _now();
    final r = await _call('${_dt}heart-rate/dataPoints:rollUp', _rollRange(now.subtract(const Duration(minutes: 20)), now, '60s'));
    final pts = _roll(r).where((p) => _n((p['heartRate'] as J?)?['beatsPerMinuteAvg']) > 0).toList()
      ..sort((a, b) => _t(b['endTime'])!.compareTo(_t(a['endTime'])!));
    if (pts.isEmpty) return null;
    return HeartNow(_n((pts.first['heartRate'] as J)['beatsPerMinuteAvg']).round(), _t(pts.first['endTime'])!);
  }

  Future<Health> fetchHealth() async {
    final now = _now();
    final midnight = _midnight(now);
    final tomorrow = midnight.add(const Duration(days: 1));
    final weekAgo = midnight.subtract(const Duration(days: 6));
    final monday = midnight.subtract(Duration(days: midnight.weekday - 1));
    final today = _daily(midnight, tomorrow);

    // Devices first: an account without a Fitbit or Pixel Watch has nothing to show.
    final devRes = await _call('${_api}pairedDevices');
    final devices = ((devRes['pairedDevices'] as List?) ?? const []).whereType<J>().map((d) => Device(
          name: (d['deviceVersion'] ?? d['deviceType'] ?? 'Tracker') as String,
          type: (d['deviceType'] ?? '') as String,
          battery: d['batteryLevel'] is num ? (d['batteryLevel'] as num).toInt() : null,
          batteryStatus: (d['batteryStatus'] ?? '') as String,
          lastSync: _t(d['lastSyncTime']),
        )).toList();

    final calls = <Future<J>>[
      _call('${_dt}heart-rate/dataPoints:rollUp', _rollRange(midnight, now, '3600s')),
      _call('${_dt}steps/dataPoints:dailyRollUp', _daily(weekAgo, tomorrow)),
      _call('${_dt}distance/dataPoints:dailyRollUp', today),
      _call('${_dt}active-energy-burned/dataPoints:dailyRollUp', today),
      _call('${_dt}active-zone-minutes/dataPoints:dailyRollUp', today),
      _call('${_dt}daily-resting-heart-rate/dataPoints?pageSize=7'),
      _call('${_dt}daily-heart-rate-variability/dataPoints?pageSize=7'),
      _call('${_dt}daily-oxygen-saturation/dataPoints?pageSize=1'),
      _call('${_dt}daily-respiratory-rate/dataPoints?pageSize=1'),
      _call('${_dt}daily-sleep-temperature-derivations/dataPoints?pageSize=1'),
      _call('${_dt}weight/dataPoints?pageSize=1'),
      _call('${_dt}sleep/dataPoints:reconcile?pageSize=7'),
      _call('${_dt}steps/dataPoints:rollUp', _rollRange(midnight, now, '3600s')),
      _call('${_dt}total-calories/dataPoints:dailyRollUp', today),
      _call('${_dt}heart-rate/dataPoints:dailyRollUp', today),
      _call('${_dt}exercise/dataPoints?pageSize=50'),
      _call('${_dt}heart-rate/dataPoints:rollUp', _rollRange(midnight, now, '300s')),
    ];
    final results = await Future.wait([...calls.map(_safe)]);
    HeartNow? latest;
    try {
      latest = await latestHeartRate();
    } on AuthExpiredError {
      rethrow;
    } on PermissionError {
      rethrow;
    } catch (_) {}
    final [hrHourly, stepsWeekR, distance, energy, azmR, resting, hrv, spo2R, respR, tempR, weightR, sleepR, stepsHourR, totalCalR, hrDayR, exerciseR, hr5R] = results;

    final hourly = _roll(hrHourly).where((p) => p['startTime'] != null).map((p) {
      final h = (p['heartRate'] as J?) ?? const {};
      return HeartHour(_t(p['startTime'])!, _n(h['beatsPerMinuteAvg']).round(), _n(h['beatsPerMinuteMin']).round(), _n(h['beatsPerMinuteMax']).round());
    }).where((h) => h.avg > 0).toList()
      ..sort((a, b) => a.at.compareTo(b.at));

    final stepsWeek = _roll(stepsWeekR).where((p) => (p['civilStartTime'] as J?)?['date'] != null).map((p) => DayValue(
          _civDate((p['civilStartTime'] as J)['date'] as J), _n((p['steps'] as J?)?['countSum']).round())).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final azmRaw = (_roll(azmR).firstOrNull?['activeZoneMinutes'] as J?) ?? const {};
    final azm = Azm(
      fatBurn: _n(azmRaw['sumInFatBurnHeartZone']).round(),
      cardio: _n(azmRaw['sumInCardioHeartZone']).round(),
      peak: _n(azmRaw['sumInPeakHeartZone']).round(),
    );

    final sleep = _pts(sleepR).map((p) => (p['sleep'] as J?) ?? p).where((s) {
      final i = s['interval'] as J?;
      return i?['startTime'] != null && i?['endTime'] != null;
    }).map(parseSleep).toList()
      ..sort((a, b) => a.end.compareTo(b.end));

    final hourSteps = _roll(stepsHourR).where((p) => p['startTime'] != null).map((p) => DayValue(_t(p['startTime'])!, _n((p['steps'] as J?)?['countSum']).round())).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Hourly activity: hours between 9 AM and 6 PM with at least 250 steps (the Fitbit rule).
    final hourlyDone = hourSteps.where((h) => h.date.hour >= 9 && h.date.hour < 18 && h.value >= 250).length;

    final hrDay = _roll(hrDayR).firstOrNull?['heartRate'] as J?;
    final avg5 = _roll(hr5R).map((p) => _n((p['heartRate'] as J?)?['beatsPerMinuteAvg'])).where((v) => v > 0).toList();
    final totalKcal = (_roll(totalCalR).firstOrNull?['totalCalories'] as J?)?['kcalSum'];
    final exDays = _pts(exerciseR).map((p) => _t(((p['exercise'] as J?)?['interval'] as J?)?['startTime'])).whereType<DateTime>()
        .where((d) => !d.isBefore(monday)).map((d) => '${d.year}-${d.month}-${d.day}').toSet();

    final spo2 = _pts(spo2R).firstOrNull?['dailyOxygenSaturation'] as J?;
    final resp = _pts(respR).firstOrNull?['dailyRespiratoryRate'] as J?;
    final temp = _pts(tempR).firstOrNull?['dailySleepTemperatureDerivations'] as J?;
    final wt = _pts(weightR).firstOrNull?['weight'] as J?;

    final health = Health(
      live: true,
      updatedAt: now,
      devices: devices,
      now: latest,
      hourly: hourly,
      resting: _pts(resting).where((p) => (p['dailyRestingHeartRate'] as J?)?['date'] != null).map((p) {
        final r = p['dailyRestingHeartRate'] as J;
        return DayValue(_civDate(r['date'] as J), _n(r['beatsPerMinute']).round());
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      hrv: _pts(hrv).where((p) => (p['dailyHeartRateVariability'] as J?)?['date'] != null).map((p) {
        final r = p['dailyHeartRateVariability'] as J;
        return DayValue(_civDate(r['date'] as J), (_n(r['averageHeartRateVariabilityMilliseconds']) * 10).round() / 10);
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date)),
      todayRange: avg5.isEmpty
          ? null
          : (
              min: avg5.reduce((a, b) => a < b ? a : b).round(),
              max: avg5.reduce((a, b) => a > b ? a : b).round(),
              avg: hrDay != null ? _n(hrDay['beatsPerMinuteAvg']).round() : (avg5.reduce((a, b) => a + b) / avg5.length).round(),
            ),
      stepsToday: stepsWeek.isEmpty ? 0 : stepsWeek.last.value,
      stepsWeek: stepsWeek,
      distanceKm: (_n((_roll(distance).firstOrNull?['distance'] as J?)?['millimetersSum']) / 10000).round() / 100,
      activeKcal: _n((_roll(energy).firstOrNull?['activeEnergyBurned'] as J?)?['kcalSum']).round(),
      totalKcal: totalKcal == null ? null : _n(totalKcal).round(),
      azm: azm,
      hourSteps: hourSteps,
      hourlyDone: hourlyDone,
      exerciseDays: exDays.length,
      sleep: sleep,
      spo2: spo2 == null ? null : (avg: _n(spo2['averagePercentage']), low: _n(spo2['lowerBoundPercentage']), high: _n(spo2['upperBoundPercentage'])),
      respRate: resp == null ? null : _n(resp['breathsPerMinute']),
      skinTempC: temp == null || temp['nightlyTemperatureCelsius'] == null ? null : (_n(temp['nightlyTemperatureCelsius']) * 10).round() / 10,
      weightKg: wt == null ? null : (_n(wt['weightGrams']) / 100).round() / 10,
    );

    final hasData = latest != null || hourly.isNotEmpty || stepsWeek.any((d) => d.value > 0) || sleep.isNotEmpty;
    if (devices.isEmpty && !hasData) throw const NoDeviceError();
    return health;
  }

  static SleepNight parseSleep(J s) {
    final interval = s['interval'] as J;
    final start = _t(interval['startTime'])!, end = _t(interval['endTime'])!;
    final stages = ((s['stages'] as List?) ?? const []).whereType<J>().map((st) {
      final k = '${st['type']}'.toUpperCase();
      final stage = switch (k) { 'AWAKE' => Stage.awake, 'LIGHT' => Stage.light, 'DEEP' => Stage.deep, 'REM' => Stage.rem, _ => null };
      final a = _t(st['startTime']), b = _t(st['endTime']);
      return stage == null || a == null || b == null ? null : StageSpan(stage, a, b);
    }).whereType<StageSpan>().toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    double total(Stage k) => stages.where((x) => x.stage == k).fold(0.0, (a, x) => a + x.minutes);
    final deep = total(Stage.deep), light = total(Stage.light), rem = total(Stage.rem), awake = total(Stage.awake);

    // Longest stretch awake in the middle of the night (joins back-to-back AWAKE stages).
    ({int minutes, DateTime at})? longest;
    DateTime? runStart, runEnd;
    void flush() {
      if (runStart != null && runEnd != null && runStart!.isAfter(start) && runEnd!.isBefore(end)) {
        final m = runEnd!.difference(runStart!).inMinutes;
        if (m >= 10 && (longest == null || m > longest!.minutes)) longest = (minutes: m, at: runStart!);
      }
      runStart = runEnd = null;
    }
    for (final st in stages) {
      if (st.stage == Stage.awake) {
        if (runEnd != null && st.start.difference(runEnd!).inSeconds <= 60) {
          runEnd = st.end;
        } else {
          flush();
          runStart = st.start;
          runEnd = st.end;
        }
      } else if (runEnd != null) {
        flush();
      }
    }
    flush();

    final meta = (s['metadata'] as J?) ?? const {};
    final asleepStages = (deep + light + rem).round();
    final asleep = asleepStages > 0 ? asleepStages : (end.difference(start).inMinutes - awake).round();
    return SleepNight(
      date: weekday(end),
      minutes: asleep,
      deep: deep.round(),
      light: light.round(),
      rem: rem.round(),
      awake: awake.round(),
      start: start,
      end: end,
      nap: (meta['nap'] == true || (meta['mainSleep'] == false && meta['nap'] != false)) ? true : (meta['mainSleep'] == true ? false : null),
      longestWake: longest,
      stages: stages,
      restless: ((s['shortAwakenings'] as List?) ?? const []).whereType<J>().map((a) {
        final x = _t(a['startTime']), y = _t(a['endTime']);
        return x == null || y == null ? null : Span(x, y);
      }).whereType<Span>().toList(),
    );
  }

  // ---------- Heart detail ----------
  Future<List<J>> _rollAll(String url, J body) async {
    final out = <J>[];
    String? pageToken;
    for (var i = 0; i < 6; i++) {
      final r = await _call(url, pageToken == null ? body : {...body, 'pageToken': pageToken});
      out.addAll(_roll(r));
      pageToken = r['nextPageToken'] as String?;
      if (pageToken == null) break;
    }
    return out;
  }

  Future<ZoneLimits> _limits() async {
    final r = await _safe(_call('${_dt}daily-heart-rate-zones/dataPoints?pageSize=1'));
    final zs = (((_pts(r).firstOrNull?['dailyHeartRateZones'] as J?)?['heartRateZones'] as List?) ?? const []).whereType<J>();
    int? min(String t) {
      final z = zs.where((z) => z['heartRateZoneType'] == t).firstOrNull;
      return z == null ? null : _n(z['minBeatsPerMinute']).round();
    }
    final m = min('MODERATE'), v = min('VIGOROUS'), p = min('PEAK');
    return m != null && v != null && p != null ? ZoneLimits(m, v, p) : ZoneLimits.fallback;
  }

  static Map<Zone, double> _zones(Iterable<J> points) {
    final out = {for (final z in Zone.values) z: 0.0};
    for (final p in points) {
      for (final z in (((p['timeInHeartRateZone'] as J?)?['timeInHeartRateZones'] as List?) ?? const []).whereType<J>()) {
        final k = switch ('${z['heartRateZone']}'.toUpperCase()) { 'LIGHT' => Zone.light, 'MODERATE' => Zone.moderate, 'VIGOROUS' => Zone.vigorous, 'PEAK' => Zone.peak, _ => null };
        if (k != null) out[k] = out[k]! + (double.tryParse('${z['duration']}'.replaceAll('s', '')) ?? 0);
      }
    }
    return out;
  }

  /// One day of heart rate in 5-minute steps, plus time in each zone.
  Future<HeartDay> heartDay(int offset) async {
    final now = _now();
    final start = _midnight(now).subtract(Duration(days: offset));
    final next = start.add(const Duration(days: 1));
    final end = offset == 0 ? now : next;
    final res = await Future.wait([
      _rollAll('${_dt}heart-rate/dataPoints:rollUp', _rollRange(start, end, '300s')),
      _call('${_dt}time-in-heart-rate-zone/dataPoints:dailyRollUp', _daily(start, next)).then((r) => _roll(r)),
    ]);
    final points = res[0].where((p) => _n((p['heartRate'] as J?)?['beatsPerMinuteAvg']) > 0).map((p) {
      final h = p['heartRate'] as J;
      return HrPoint(_t(p['startTime'])!, _n(h['beatsPerMinuteAvg']), _n(h['beatsPerMinuteMin']), _n(h['beatsPerMinuteMax']));
    }).toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    return HeartDay(start: start, end: next, points: points, limits: await _limits(), zoneSeconds: _zones(res[1].take(1)));
  }

  /// The last 7 days as daily lowest-to-highest ranges.
  Future<HeartWeek> heartWeek() async {
    final midnight = _midnight(_now());
    final body = _daily(midnight.subtract(const Duration(days: 6)), midnight.add(const Duration(days: 1)));
    final res = await Future.wait([
      _call('${_dt}heart-rate/dataPoints:dailyRollUp', body),
      _call('${_dt}time-in-heart-rate-zone/dataPoints:dailyRollUp', body),
    ]);
    final days = _roll(res[0]).where((p) => (p['civilStartTime'] as J?)?['date'] != null && _n((p['heartRate'] as J?)?['beatsPerMinuteAvg']) > 0).map((p) {
      final h = p['heartRate'] as J;
      return HeartWeekDay(_civDate((p['civilStartTime'] as J)['date'] as J), _n(h['beatsPerMinuteMin']).round(), _n(h['beatsPerMinuteMax']).round(), _n(h['beatsPerMinuteAvg']).round());
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return HeartWeek(days: days, limits: await _limits(), zoneSeconds: _zones(_roll(res[1])));
  }
}
