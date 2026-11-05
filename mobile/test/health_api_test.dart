import 'dart:convert';
import 'package:basivo_fit/data/health_api.dart';
import 'package:basivo_fit/data/models.dart';
import 'package:basivo_fit/data/sleep_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Response shapes copied from real Google Health API v4 replies (values changed).
final now = DateTime(2026, 11, 4, 23, 30);
String iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, Object?> sleepRecord() {
  final s = DateTime(2026, 11, 4, 1, 11);
  final plan = [
    ('AWAKE', 2),
    ('LIGHT', 12),
    ('DEEP', 12),
    ('LIGHT', 30),
    ('REM', 20),
    ('AWAKE', 50),
    ('LIGHT', 60),
    ('DEEP', 20),
    ('REM', 30),
    ('LIGHT', 40),
  ];
  var t = s;
  final stages = <Map<String, Object?>>[];
  for (final (k, m) in plan) {
    final e = t.add(Duration(minutes: m));
    stages.add({'startTime': iso(t), 'endTime': iso(e), 'type': k});
    t = e;
  }
  return {
    'sleep': {
      'interval': {'startTime': iso(s), 'endTime': iso(t)},
      'type': 'STAGES',
      'stages': stages,
      'metadata': {
        'stagesStatus': 'SUCCEEDED',
        'processed': true,
        'mainSleep': true,
      },
      'shortAwakenings': [
        {
          'startTime': iso(s.add(const Duration(minutes: 30))),
          'endTime': iso(s.add(const Duration(minutes: 33))),
          'type': 'LIGHT',
        },
        {
          'startTime': iso(s.add(const Duration(minutes: 200))),
          'endTime': iso(s.add(const Duration(minutes: 201))),
          'type': 'LIGHT',
        },
      ],
    },
  };
}

http.Response route(http.Request r, {bool devices = true, bool data = true}) {
  final p = r.url.path + (r.url.query.isEmpty ? '' : '?${r.url.query}');
  final body = r.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(r.body) as Map<String, dynamic>;
  Map<String, Object?> out = {};
  if (p.endsWith('pairedDevices')) {
    out = devices
        ? {
            'pairedDevices': [
              {
                'deviceVersion': 'Fitbit Air',
                'deviceType': 'TRACKER',
                'batteryLevel': 54,
                'lastSyncTime': iso(now),
              },
            ],
          }
        : {};
  } else if (!data) {
    out = {};
  } else if (p.contains('heart-rate/dataPoints:rollUp')) {
    final w = body['windowSize'];
    if (w == '60s') {
      out = {
        'rollupDataPoints': [
          {
            'startTime': iso(now.subtract(const Duration(minutes: 3))),
            'endTime': iso(now.subtract(const Duration(minutes: 2))),
            'heartRate': {'beatsPerMinuteAvg': 70.4},
          },
          {
            'startTime': iso(now.subtract(const Duration(minutes: 9))),
            'endTime': iso(now.subtract(const Duration(minutes: 8))),
            'heartRate': {'beatsPerMinuteAvg': 93.0},
          },
        ],
      };
    } else if (w == '300s') {
      out = {
        'rollupDataPoints': [
          {
            'startTime': iso(DateTime(2026, 11, 4, 10)),
            'heartRate': {
              'beatsPerMinuteAvg': 57.2,
              'beatsPerMinuteMin': 53,
              'beatsPerMinuteMax': 61,
            },
          },
          {
            'startTime': iso(DateTime(2026, 11, 4, 12)),
            'heartRate': {
              'beatsPerMinuteAvg': 121.8,
              'beatsPerMinuteMin': 110,
              'beatsPerMinuteMax': 140,
            },
          },
          {
            'startTime': iso(DateTime(2026, 11, 4, 12, 5)),
            'heartRate': {
              'beatsPerMinuteAvg': 80.0,
              'beatsPerMinuteMin': 74,
              'beatsPerMinuteMax': 88,
            },
          },
        ],
      };
    } else {
      out = {
        'rollupDataPoints': [
          {
            'startTime': iso(DateTime(2026, 11, 4, 9)),
            'endTime': iso(DateTime(2026, 11, 4, 10)),
            'heartRate': {
              'beatsPerMinuteAvg': 66.0,
              'beatsPerMinuteMin': 53,
              'beatsPerMinuteMax': 90,
            },
          },
        ],
      };
    }
  } else if (p.contains('heart-rate/dataPoints:dailyRollUp')) {
    out = {
      'rollupDataPoints': [
        {
          'civilStartTime': {
            'date': {'year': 2026, 'month': 11, 'day': 4},
          },
          'heartRate': {
            'beatsPerMinuteAvg': 74.09,
            'beatsPerMinuteMax': 140,
            'beatsPerMinuteMin': 53,
          },
        },
      ],
    };
  } else if (p.contains('steps/dataPoints:dailyRollUp')) {
    out = {
      'rollupDataPoints': [
        {
          'civilStartTime': {
            'date': {'year': 2026, 'month': 11, 'day': 4},
          },
          'steps': {'countSum': '1853'},
        },
        {
          'civilStartTime': {
            'date': {'year': 2026, 'month': 11, 'day': 3},
          },
          'steps': {'countSum': '5120'},
        },
      ],
    };
  } else if (p.contains('steps/dataPoints:rollUp')) {
    out = {
      'rollupDataPoints': [
        {
          'startTime': iso(DateTime(2026, 11, 4, 8)),
          'steps': {'countSum': '600'},
        },
        {
          'startTime': iso(DateTime(2026, 11, 4, 10)),
          'steps': {'countSum': '380'},
        },
        {
          'startTime': iso(DateTime(2026, 11, 4, 11)),
          'steps': {'countSum': '151'},
        },
      ],
    };
  } else if (p.contains('distance/')) {
    out = {
      'rollupDataPoints': [
        {
          'distance': {'millimetersSum': '1390000'},
        },
      ],
    };
  } else if (p.contains('active-energy-burned/')) {
    out = {
      'rollupDataPoints': [
        {
          'activeEnergyBurned': {'kcalSum': 153.4},
        },
      ],
    };
  } else if (p.contains('total-calories/')) {
    out = {
      'rollupDataPoints': [
        {
          'totalCalories': {'kcalSum': 2053.2},
        },
      ],
    };
  } else if (p.contains('active-zone-minutes/')) {
    out = {
      'rollupDataPoints': [
        {
          'activeZoneMinutes': {
            'sumInFatBurnHeartZone': '17',
            'sumInCardioHeartZone': '3',
          },
        },
      ],
    };
  } else if (p.contains('daily-resting-heart-rate/')) {
    out = {
      'dataPoints': [
        {
          'dailyRestingHeartRate': {
            'date': {'year': 2026, 'month': 11, 'day': 4},
            'beatsPerMinute': '65',
          },
        },
      ],
    };
  } else if (p.contains('daily-heart-rate-variability/')) {
    out = {
      'dataPoints': [
        {
          'dailyHeartRateVariability': {
            'date': {'year': 2026, 'month': 11, 'day': 4},
            'averageHeartRateVariabilityMilliseconds': 26.54,
          },
        },
      ],
    };
  } else if (p.contains('daily-oxygen-saturation/')) {
    out = {
      'dataPoints': [
        {
          'dailyOxygenSaturation': {
            'averagePercentage': 96.3,
            'lowerBoundPercentage': 95,
            'upperBoundPercentage': 97.7,
          },
        },
      ],
    };
  } else if (p.contains('sleep/dataPoints:reconcile')) {
    out = {
      'dataPoints': [sleepRecord()],
    };
  } else if (p.contains('time-in-heart-rate-zone/')) {
    out = {
      'rollupDataPoints': [
        {
          'timeInHeartRateZone': {
            'timeInHeartRateZones': [
              {'heartRateZone': 'LIGHT', 'duration': '81660s'},
              {'heartRateZone': 'MODERATE', 'duration': '1020s'},
            ],
          },
        },
      ],
    };
  } else if (p.contains('daily-heart-rate-zones/')) {
    out = {
      'dataPoints': [
        {
          'dailyHeartRateZones': {
            'heartRateZones': [
              {'heartRateZoneType': 'LIGHT', 'minBeatsPerMinute': '30'},
              {'heartRateZoneType': 'MODERATE', 'minBeatsPerMinute': '116'},
              {'heartRateZoneType': 'VIGOROUS', 'minBeatsPerMinute': '142'},
              {'heartRateZoneType': 'PEAK', 'minBeatsPerMinute': '174'},
            ],
          },
        },
      ],
    };
  } else if (p.contains('exercise/')) {
    out = {
      'dataPoints': [
        {
          'exercise': {
            'interval': {'startTime': iso(DateTime(2026, 11, 3, 18))},
          },
        },
      ],
    };
  }
  return http.Response(jsonEncode(out), 200);
}

HealthApi apiWith(MockClient c) =>
    HealthApi(token: () async => 't0k', client: c, clock: () => now);

void main() {
  test('fetchHealth parses every metric', () async {
    final h = await apiWith(MockClient((r) async => route(r))).fetchHealth();
    expect(h.devices.single.name, 'Fitbit Air');
    expect(h.devices.single.battery, 54);
    expect(h.stepsToday, 1853);
    expect(h.stepsWeek.first.value, 5120, reason: 'sorted oldest first');
    expect(h.distanceKm, 1.39);
    expect(h.activeKcal, 153);
    expect(h.totalKcal, 2053);
    expect(h.azm.total, 17 + 6);
    expect(h.now!.bpm, 70, reason: 'newest 1-minute window wins');
    expect(
      h.todayRange!.max,
      122,
      reason: 'range uses smoothed 5-minute averages, not the 140 raw spike',
    );
    expect(h.todayRange!.min, 57);
    expect(h.resting.single.value, 65);
    expect(h.hrv.single.value, 26.5);
    expect(h.spo2!.avg, 96.3);
    expect(h.hourlyDone, 1, reason: 'only 10 AM is inside 9-6 with 250+ steps');
    expect(h.exerciseDays, 1);
  });

  test('sleep stages, long wake-up and quality rules', () async {
    final h = await apiWith(MockClient((r) async => route(r))).fetchHealth();
    final n = h.mainSleep!;
    expect(n.deep, 32);
    expect(n.rem, 50);
    expect(n.light, 142);
    expect(n.minutes, 224);
    expect(n.isNap, isFalse, reason: 'metadata.mainSleep wins over duration');
    expect(n.longestWake!.minutes, 50);
    expect(n.restless.length, 2);
    final q = sleepQuality(n);
    expect(q[0].value, '14 min');
    expect(q[0].status, QStatus.ok);
    expect(q[2].value, '4 min');
    expect(q[3].value, '50 min, 1 time');
    expect(q[3].status, QStatus.high);
    expect(dailyTip(h), contains('awake for 50 minutes'));
  });

  test('no device and no data shows the no-device problem', () async {
    expect(
      () => apiWith(
        MockClient((r) async => route(r, devices: false, data: false)),
      ).fetchHealth(),
      throwsA(isA<NoDeviceError>()),
    );
  });

  test('401 means the sign-in expired, 403 means missing permission', () async {
    expect(
      () => apiWith(
        MockClient((r) async => http.Response('{}', 401)),
      ).fetchHealth(),
      throwsA(isA<AuthExpiredError>()),
    );
    expect(
      () => apiWith(
        MockClient((r) async => http.Response('{}', 403)),
      ).fetchHealth(),
      throwsA(isA<PermissionError>()),
    );
  });

  test('one failing data type does not break the rest', () async {
    final h = await apiWith(
      MockClient(
        (r) async => r.url.path.contains('weight')
            ? http.Response('oops', 500)
            : route(r),
      ),
    ).fetchHealth();
    expect(h.weightKg, isNull);
    expect(h.stepsToday, 1853);
  });

  test('sends the bearer token and JSON bodies', () async {
    final seen = <http.Request>[];
    await apiWith(
      MockClient((r) async {
        seen.add(r);
        return route(r);
      }),
    ).fetchHealth();
    expect(
      seen.every((r) => r.headers['Authorization'] == 'Bearer t0k'),
      isTrue,
    );
    final daily = seen.firstWhere(
      (r) => r.url.path.contains('steps/dataPoints:dailyRollUp'),
    );
    expect(jsonDecode(daily.body)['range']['start']['date'], {
      'year': 2026,
      'month': 10,
      'day': 29,
    });
  });

  test('heart day: zones, limits and smoothed range', () async {
    final d = await apiWith(MockClient((r) async => route(r))).heartDay(0);
    expect(d.limits.moderate, 116);
    expect(d.limits.peak, 174);
    expect(d.zoneSeconds[Zone.moderate], 1020);
    expect(d.max, 122);
    expect(d.limits.zoneOf(122), Zone.moderate);
    expect(d.points.first.t.isBefore(d.points.last.t), isTrue);
  });
}
