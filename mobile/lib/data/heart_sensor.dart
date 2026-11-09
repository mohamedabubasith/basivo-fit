import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  const SensorDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.advertisesHr = true,
  });
  final String id, name;
  final int? rssi;

  /// False for devices found by name only (for example a Fitbit band) that did
  /// not announce the heart rate service: they may need sharing turned on first.
  final bool advertisesHr;
}

/// Names of wearables that can share heart rate but may not announce the
/// heart rate service in their advertisement (Fitbit Air, Charge 6, Pixel Watch...).
final _wearableName = RegExp(
  r'fitbit|\bair\b|charge|pixel watch|inspire|versa|sense|polar|wahoo|tickr|garmin|coros|whoop|amazfit|suunto|\bhrm|heart',
  caseSensitive: false,
);

/// True when an advertisement looks like a heart rate source: it announces the
/// standard Heart Rate Service, or its name is a known wearable.
bool looksLikeHeartRate(String name, bool advertisesHr) =>
    advertisesHr || (name.isNotEmpty && _wearableName.hasMatch(name));

enum SensorStatus {
  unknown,
  unsupported,
  unauthorized,
  bluetoothOff,
  locationOff,
  ready,
}

enum LinkState { connecting, connected, disconnected }

/// The last Bluetooth steps and errors, shown under "Connection details" so a
/// failed connection can be diagnosed from a screenshot.
final bleLog = ValueNotifier<List<String>>(const []);

void logBle(String msg) {
  final t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final line = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $msg';
  final l = [...bleLog.value, line];
  bleLog.value = l.length > 40 ? l.sublist(l.length - 40) : l;
}

/// What the live screen needs from a heart rate sensor, so it can be faked in demo mode and tests.
abstract class HeartSensor {
  bool get available;
  Stream<SensorStatus> status();
  Future<bool> requestPermission();
  Stream<SensorDevice> scan();
  Stream<LinkState> connect(String deviceId);
  Stream<HrReading> readings(String deviceId);

  /// After connecting: whether the device really offers the Heart Rate Service.
  Future<bool> hasHeartRate(String deviceId);

  /// Secure pairing, for bands that only send heart rate to a paired phone.
  /// Returns true when a new pairing was made (the link should be reopened).
  Future<bool> ensureBonded(String deviceId);

  /// Clears a stuck or stale pairing with the device.
  Future<bool> resetPairing(String deviceId);
}

final _hrService = Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');
final _hrMeasurement = Uuid.parse('00002a37-0000-1000-8000-00805f9b34fb');

/// Real Bluetooth sensor (Android and iPhone).
class BleHeartSensor implements HeartSensor {
  final _ble = FlutterReactiveBle();
  static const _native = MethodChannel('basivo/ble');
  final _seen = <String>{};
  final _pairTried = <String>{};
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

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
  Stream<SensorDevice> scan() {
    _seen.clear();
    logBle('Searching for heart rate devices');
    return _scanAll();
  }

  Stream<SensorDevice> _scanAll() => _ble
      // Scan everything, not only devices that list 0x180D in the advertisement:
      // some bands (Fitbit, Pixel Watch) put it in the scan response or only expose
      // it after connecting, and a service filter would hide them.
      .scanForDevices(
        withServices: const [],
        scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: false,
      )
      .where(
        (d) => looksLikeHeartRate(d.name, d.serviceUuids.contains(_hrService)),
      )
      .map((d) {
        if (_seen.add(d.id)) {
          logBle(
            'Found ${d.name.isEmpty ? '(no name)' : d.name}  ${d.id}  '
            '${d.serviceUuids.contains(_hrService) ? 'sharing HR' : 'HR not announced'}  ${d.rssi} dBm',
          );
        }
        return d;
      })
      .map(
        (d) => SensorDevice(
          id: d.id,
          name: d.name.isEmpty ? 'Heart rate sensor' : d.name,
          rssi: d.rssi,
          advertisesHr: d.serviceUuids.contains(_hrService),
        ),
      );

  @override
  Future<bool> hasHeartRate(String deviceId) async {
    try {
      await _ble.discoverAllServices(deviceId);
      final services = await _ble.getDiscoveredServices(deviceId);
      final ok = services.any((s) => s.id == _hrService);
      logBle(
        'Services: ${services.length} found, heart rate ${ok ? 'yes' : 'NO'}',
      );
      logBle('Service ids: ${services.map((s) => _short(s.id)).join(' ')}');
      for (final s in services.where((s) => s.id == _hrService)) {
        for (final ch in s.characteristics) {
          logBle(
            'HR char ${_short(ch.id)}: '
            '${[if (ch.isNotifiable) 'notify', if (ch.isIndicatable) 'indicate', if (ch.isReadable) 'read', if (ch.isWritableWithResponse || ch.isWritableWithoutResponse) 'write'].join('/')}',
          );
        }
      }
      return ok;
    } catch (e) {
      // If discovery itself fails, let the subscription decide.
      logBle('Service discovery failed: $e');
      return true;
    }
  }

  @override
  Future<bool> ensureBonded(String deviceId) async {
    if (!_android) return false;
    // Ask at most once per device per session: a band that ignores pairing
    // (Fitbit Air does) should not hold up the connection every time.
    if (!_pairTried.add(deviceId)) return false;
    try {
      var state = await _native.invokeMethod<int>('bondState', {
        'id': deviceId,
      });
      if (state == 12) {
        logBle('Already paired');
        return false;
      }
      logBle('No heart rate yet: asking Android to pair (state $state)');
      for (final method in ['createBond', 'createBondDefault']) {
        final started = await _native.invokeMethod<bool>(method, {
          'id': deviceId,
        });
        logBle(
          '${method == 'createBond' ? 'LE pairing' : 'Standard pairing'}: '
          '${started == true ? 'started, tap Pair if asked' : 'Android refused to start'}',
        );
        var last = state;
        for (var i = 0; i < 25; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          state = await _native.invokeMethod<int>('bondState', {
            'id': deviceId,
          });
          if (state != last) {
            logBle('Pairing state ${_bondName(state)} after ${i + 1} s');
            last = state;
          }
          if (state == 12 || (state == 10 && i >= 3)) break;
        }
        if (state == 12) break;
      }
      logBle(
        state == 12 ? 'Paired' : 'Pairing failed: the band did not accept it',
      );
      return state == 12;
    } catch (e) {
      logBle('Pairing error: $e');
      return false;
    }
  }

  /// Subscribes to every Heart Rate Measurement characteristic the device has
  /// (some devices expose more than one, which the single lookup rejects).
  Stream<List<int>> _subscribeAll(String deviceId) async* {
    final chars = (await _ble.getDiscoveredServices(deviceId))
        .where((s) => s.id == _hrService)
        .expand((s) => s.characteristics)
        .where((c) => c.id == _hrMeasurement)
        .toList();
    if (chars.isEmpty) {
      throw Exception('Heart Rate Measurement characteristic not found');
    }
    logBle('Subscribing to ${chars.length} heart rate characteristic(s)');
    if (chars.length == 1) {
      yield* chars.single.subscribe();
      return;
    }
    final ctl = StreamController<List<int>>();
    final subs = [
      for (final c in chars)
        c.subscribe().listen(ctl.add, onError: ctl.addError),
    ];
    ctl.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    yield* ctl.stream;
  }

  static String _bondName(int? s) => switch (s) {
    10 => 'not paired',
    11 => 'pairing…',
    12 => 'paired',
    _ => '$s',
  };

  static String _short(Uuid u) {
    final s = u.toString();
    return s.length >= 8 && s.endsWith('-0000-1000-8000-00805f9b34fb')
        ? s.substring(4, 8)
        : s.substring(0, 8);
  }

  @override
  Future<bool> resetPairing(String deviceId) async {
    if (!_android) return false;
    try {
      final ok =
          await _native.invokeMethod<bool>('removeBond', {'id': deviceId}) ??
          false;
      logBle(ok ? 'Old pairing removed' : 'No pairing to remove');
      return ok;
    } catch (e) {
      logBle('Reset pairing error: $e');
      return false;
    }
  }

  @override
  Stream<LinkState> connect(String deviceId) {
    logBle('Connecting to $deviceId');
    // Connect the moment the device is seen advertising: bands such as the
    // Fitbit Air rotate their private address, so an address from an older
    // scan can be stale.
    return _ble
        .connectToAdvertisingDevice(
          id: deviceId,
          withServices: const [],
          prescanDuration: const Duration(seconds: 6),
          connectionTimeout: const Duration(seconds: 20),
        )
        .map((u) {
          final f = u.failure;
          logBle(
            'Link: ${u.connectionState.name}${f == null ? '' : '  error ${f.code.name}: ${f.message}'}',
          );
          return switch (u.connectionState) {
            DeviceConnectionState.connecting => LinkState.connecting,
            DeviceConnectionState.connected => LinkState.connected,
            _ => LinkState.disconnected,
          };
        })
        .handleError((Object e) {
          logBle('Link error: $e');
          throw e;
        });
  }

  @override
  Stream<HrReading> readings(String deviceId) {
    logBle('Listening for heart rate');
    var first = true;
    var packets = 0;
    return _subscribeAll(deviceId)
        .map((b) {
          packets++;
          if (packets <= 3 || packets % 30 == 0) {
            logBle(
              'Packet $packets: ${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ')}',
            );
          }
          return b;
        })
        .map(parseHeartRate)
        .where((r) => r != null && r.bpm > 0)
        .cast<HrReading>()
        .map((r) {
          if (first) {
            first = false;
            logBle('First heart rate: ${r.bpm} bpm');
          }
          return r;
        })
        .handleError((Object e) {
          logBle('Heart rate error: $e');
          throw e;
        });
  }
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
  Future<bool> hasHeartRate(String deviceId) async => true;

  @override
  Future<bool> ensureBonded(String deviceId) async => false;

  @override
  Future<bool> resetPairing(String deviceId) async => true;

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
