import 'dart:async';
import 'package:basivo_fit/data/heart_sensor.dart';
import 'package:basivo_fit/state/live_heart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSensor implements HeartSensor {
  FakeSensor({this.state = SensorStatus.ready, this.grant = true});
  SensorStatus state;
  bool grant;
  int permissionAsks = 0, connects = 0;
  final readingsCtl = StreamController<HrReading>.broadcast();
  final linkCtl = StreamController<LinkState>.broadcast();
  @override
  bool get available => true;
  @override
  Stream<SensorStatus> status() => Stream.value(state);
  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    if (grant) state = SensorStatus.ready;
    return grant;
  }

  @override
  Stream<SensorDevice> scan() => Stream.fromIterable(const [
    SensorDevice(id: 'a', name: 'Far strap', rssi: -80),
    SensorDevice(id: 'b', name: 'Near strap', rssi: -40),
  ]);
  @override
  Stream<LinkState> connect(String deviceId) {
    connects++;
    scheduleMicrotask(() => linkCtl.add(LinkState.connected));
    return linkCtl.stream;
  }

  @override
  Stream<HrReading> readings(String deviceId) => readingsCtl.stream;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Heart Rate Measurement parser', () {
    test('8-bit heart rate', () {
      final r = parseHeartRate([0x00, 72])!;
      expect(r.bpm, 72);
      expect(r.rrMs, isEmpty);
      expect(r.contact, isNull);
    });
    test('16-bit heart rate with skin contact', () {
      final r = parseHeartRate([
        0x07,
        0x2C,
        0x01,
      ])!; // 300 bpm, contact supported and detected
      expect(r.bpm, 300);
      expect(r.contact, isTrue);
    });
    test('contact supported but not detected', () {
      expect(parseHeartRate([0x04, 80])!.contact, isFalse);
    });
    test('RR intervals after an energy field', () {
      // flags: RR present (0x10) + energy present (0x08); bpm 60; energy 0x0102; RR 1024 and 512 (1/1024 s)
      final r = parseHeartRate([0x18, 60, 0x02, 0x01, 0x00, 0x04, 0x00, 0x02])!;
      expect(r.bpm, 60);
      expect(r.rrMs, [1000.0, 500.0]);
    });
    test('malformed packets are ignored', () {
      expect(parseHeartRate([]), isNull);
      expect(parseHeartRate([0x01, 0x10]), isNull);
    });
    test('RMSSD needs at least 3 clean intervals', () {
      expect(rmssd([800, 810]), isNull);
      expect(rmssd([800, 820, 800, 820])!.round(), 20);
      expect(
        rmssd([800, 100, 3000, 820]),
        isNull,
        reason: 'out-of-range intervals are dropped, leaving too few',
      );
    });
  });

  group('LiveHeart controller', () {
    test('scan sorts by signal, connect goes live and keeps stats', () async {
      final f = FakeSensor();
      final live = LiveHeart(real: f);
      await live.startScan();
      await pumpEventQueue();
      expect(live.found.map((d) => d.name), ['Near strap', 'Far strap']);
      await live.connect(live.found.first);
      await pumpEventQueue();
      expect(live.phase, LivePhase.connecting);
      final t0 = DateTime.now();
      for (final (i, b) in [70, 90, 80].indexed) {
        f.readingsCtl.add(
          HrReading(
            bpm: b,
            at: t0.add(Duration(seconds: i)),
            rrMs: [60000 / b],
          ),
        );
        await pumpEventQueue();
      }
      expect(live.phase, LivePhase.live);
      expect(live.latest!.bpm, 80);
      expect((live.sessionMin, live.sessionAvg, live.sessionMax), (70, 80, 90));
      expect(live.hrv, isNotNull);
      expect(
        (await SharedPreferences.getInstance()).getString('ble.id'),
        'b',
        reason: 'remembered for next time',
      );
      await live.stop(forget: true);
      expect(live.phase, LivePhase.idle);
      expect(
        (await SharedPreferences.getInstance()).getString('ble.id'),
        isNull,
      );
    });

    test('keeps only the last 2 minutes', () async {
      final f = FakeSensor();
      final live = LiveHeart(real: f);
      await live.connect(const SensorDevice(id: 'x', name: 'X'));
      await pumpEventQueue();
      final t0 = DateTime.now();
      for (var i = 0; i < 200; i++) {
        f.readingsCtl.add(HrReading(bpm: 70, at: t0.add(Duration(seconds: i))));
      }
      await pumpEventQueue();
      expect(live.history.length, 121);
    });

    test('asks for permission and reports a refusal', () async {
      final f = FakeSensor(state: SensorStatus.unauthorized, grant: false);
      final live = LiveHeart(real: f);
      await live.startScan();
      expect(f.permissionAsks, 1);
      expect(live.phase, LivePhase.needsPermission);
    });

    test('Bluetooth off is reported', () async {
      final live = LiveHeart(
        real: FakeSensor(state: SensorStatus.bluetoothOff),
      );
      await live.startScan();
      expect(live.phase, LivePhase.bluetoothOff);
    });

    test('a dropped connection reconnects by itself', () async {
      final f = FakeSensor();
      final live = LiveHeart(
        real: f,
        retryDelay: const Duration(milliseconds: 50),
      );
      await live.connect(const SensorDevice(id: 'x', name: 'X'));
      await pumpEventQueue();
      f.linkCtl.add(LinkState.disconnected);
      await pumpEventQueue();
      expect(live.phase, LivePhase.lost);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpEventQueue();
      expect(f.connects, 2);
      expect(live.phase, isNot(LivePhase.lost));
      await live.stop();
    });
  });
}
