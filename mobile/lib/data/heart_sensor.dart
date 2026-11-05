import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

/// One reading from the standard Bluetooth Heart Rate Measurement (0x2A37).
class HrReading {
  const HrReading({
    required this.bpm,
    required this.at,
    this.rrMs = const [],
    this.contact,
  });
  final int bpm;
  final DateTime at;
  final List<double> rrMs;
  final bool? contact;
}

/// Parses a Heart Rate Measurement packet (Bluetooth Heart Rate Service 1.0):
/// byte 0 flags; bit 0 = 16-bit bpm, bits 1-2 = skin contact, bit 3 = energy field, bit 4 = RR intervals.
HrReading? parseHeartRate(List<int> b, [DateTime? at]) {
  if (b.isEmpty) return null;
  final flags = b[0];
  var i = 1;
  int bpm;
  if (flags & 0x01 == 0) {
    if (b.length < 2) return null;
    bpm = b[1];
    i = 2;
  } else {
    if (b.length < 3) return null;
    bpm = b[1] | (b[2] << 8);
    i = 3;
  }
  final contactSupported = flags & 0x04 != 0;
  final contact = contactSupported ? flags & 0x02 != 0 : null;
  if (flags & 0x08 != 0) i += 2; // energy expended, not used
  final rr = <double>[];
  if (flags & 0x10 != 0) {
    for (; i + 1 < b.length; i += 2) {
      rr.add((b[i] | (b[i + 1] << 8)) * 1000 / 1024);
    }
  }
  return HrReading(
    bpm: bpm,
    at: at ?? DateTime.now(),
    rrMs: rr,
    contact: contact,
  );
}

/// RMSSD (a common heart rate variability measure) from beat-to-beat intervals.
double? rmssd(List<double> rr) {
  final v = rr.where((x) => x > 300 && x < 2000).toList();
  if (v.length < 3) return null;
  var sum = 0.0;
  for (var i = 1; i < v.length; i++) {
    final d = v[i] - v[i - 1];
    sum += d * d;
  }
  return math.sqrt(sum / (v.length - 1));
}

class SensorDevice {
  const SensorDevice({required this.id, required this.name, this.rssi});
  final String id, name;
  final int? rssi;
}

enum SensorStatus {
  unknown,
  unsupported,
  unauthorized,
  bluetoothOff,
  locationOff,
  ready,
}

enum LinkState { connecting, connected, disconnected }

/// What the live screen needs from a heart rate sensor, so it can be faked in demo mode and tests.
abstract class HeartSensor {
  bool get available;
  Stream<SensorStatus> status();
  Future<bool> requestPermission();
  Stream<SensorDevice> scan();
  Stream<LinkState> connect(String deviceId);
  Stream<HrReading> readings(String deviceId);
}

final _hrService = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
final _hrMeasurement = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

/// Real Bluetooth sensor (Android and iPhone).
class BleHeartSensor implements HeartSensor {
  final _ble = FlutterReactiveBle();

  @override
  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<SensorStatus> status() => _ble.statusStream.map(
    (s) => switch (s) {
      BleStatus.ready => SensorStatus.ready,
      BleStatus.poweredOff => SensorStatus.bluetoothOff,
      BleStatus.unauthorized => SensorStatus.unauthorized,
      BleStatus.unsupported => SensorStatus.unsupported,
      BleStatus.locationServicesDisabled => SensorStatus.locationOff,
      _ => SensorStatus.unknown,
    },
  );

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (await Permission.bluetooth.request()).isGranted;
    }
    final r = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (r.values.every((s) => s.isGranted)) return true;
    // Android 11 and older need location permission to scan for Bluetooth devices.
    return (await Permission.locationWhenInUse.request()).isGranted;
  }

  @override
  Stream<SensorDevice> scan() => _ble
      .scanForDevices(
        withServices: [_hrService],
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: false,
      )
      .map(
        (d) => SensorDevice(
          id: d.id,
          name: d.name.isEmpty ? 'Heart rate sensor' : d.name,
          rssi: d.rssi,
        ),
      );

  @override
  Stream<LinkState> connect(String deviceId) => _ble
      .connectToDevice(
        id: deviceId,
        servicesWithCharacteristicsToDiscover: {
          _hrService: [_hrMeasurement],
        },
        connectionTimeout: const Duration(seconds: 15),
      )
      .map(
        (u) => switch (u.connectionState) {
          DeviceConnectionState.connecting => LinkState.connecting,
          DeviceConnectionState.connected => LinkState.connected,
          _ => LinkState.disconnected,
        },
      );

  @override
  Stream<HrReading> readings(String deviceId) => _ble
      .subscribeToCharacteristic(
        QualifiedCharacteristic(
          serviceId: _hrService,
          characteristicId: _hrMeasurement,
          deviceId: deviceId,
        ),
      )
      .map(parseHeartRate)
      .where((r) => r != null && r.bpm > 0)
      .cast<HrReading>();
}

/// A pretend chest strap for demo mode and tests: a resting rate that drifts, with a short climb.
class SimulatedHeartSensor implements HeartSensor {
  SimulatedHeartSensor({this.interval = const Duration(seconds: 1)});
  final Duration interval;
  @override
  bool get available => true;
  @override
  Stream<SensorStatus> status() => Stream.value(SensorStatus.ready);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<SensorDevice> scan() async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    yield const SensorDevice(
      id: 'demo-strap',
      name: 'Demo chest strap',
      rssi: -48,
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield const SensorDevice(
      id: 'demo-watch',
      name: 'Demo watch (broadcast)',
      rssi: -67,
    );
  }

  @override
  Stream<LinkState> connect(String deviceId) {
    // Stays connected until the listener cancels.
    late final StreamController<LinkState> ctl;
    Timer? t;
    ctl = StreamController<LinkState>(
      onListen: () {
        ctl.add(LinkState.connecting);
        t = Timer(
          const Duration(milliseconds: 700),
          () => ctl.add(LinkState.connected),
        );
      },
      onCancel: () => t?.cancel(),
    );
    return ctl.stream;
  }

  @override
  Stream<HrReading> readings(String deviceId) async* {
    final rnd = math.Random(7);
    var t = 0;
    while (true) {
      await Future<void>.delayed(interval);
      t++;
      final climb = (t % 60) > 35 ? ((t % 60) - 35) * 1.6 : 0.0;
      final bpm = (72 + 4 * math.sin(t / 6) + climb + rnd.nextInt(3)).round();
      final rr = 60000 / bpm;
      yield HrReading(
        bpm: bpm,
        at: DateTime.now(),
        rrMs: [rr + rnd.nextDouble() * 40 - 20],
        contact: true,
      );
    }
  }
}
