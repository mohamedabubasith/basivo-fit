import 'package:basivo_fit/data/models.dart';
import 'package:basivo_fit/data/sleep_quality.dart';
import 'package:flutter_test/flutter_test.dart';

SleepNight night({
  required int deep,
  required int rem,
  required int light,
  required int awake,
}) {
  final start = DateTime(2026, 11, 8, 23);
  final asleep = deep + rem + light;
  return SleepNight(
    date: '2026-11-09',
    minutes: asleep,
    deep: deep,
    light: light,
    rem: rem,
    awake: awake,
    start: start,
    end: start.add(Duration(minutes: asleep + awake)),
  );
}

void main() {
  test('stage shares and typical ranges', () {
    // The night from the screenshot: 4h 8m asleep, 39 min awake.
    final s = stageStats(night(deep: 50, rem: 29, light: 169, awake: 39));
    final by = {for (final x in s) x.name: x};
    expect(by['Deep']!.pct.round(), 20);
    expect(by['Deep']!.level, Level.typical);
    expect(by['REM']!.pct.round(), 12);
    expect(by['REM']!.level, Level.low);
    expect(by['Light']!.level, Level.high);
    expect(by['Awake']!.pct.round(), 14, reason: 'share of time in bed');
    expect(by['Awake']!.level, Level.high);
  });

  test('verdict is plain and specific', () {
    expect(
      sleepVerdict(night(deep: 50, rem: 29, light: 169, awake: 39)),
      'Short night. Deep sleep was good, but REM was low. '
      'You were awake quite a bit. Aim for 7 hours or more.',
    );
    expect(
      sleepVerdict(night(deep: 80, rem: 100, light: 260, awake: 20)),
      'Good length. You got enough deep sleep and REM.',
    );
  });

  test('checks read as outcomes', () {
    final k = sleepChecks(night(deep: 60, rem: 90, light: 270, awake: 15));
    expect(k, hasLength(3));
    expect(k[1].title, 'No long wake-ups');
    expect(k[2].title, 'Restless for 0 min');
    expect(k.every((x) => x.ok), isTrue);
  });
}
