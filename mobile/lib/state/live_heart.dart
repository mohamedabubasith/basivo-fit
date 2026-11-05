import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/heart_sensor.dart';

enum LivePhase {
  idle,
  needsPermission,
  bluetoothOff,
  locationOff,
  unsupported,
  scanning,
  connecting,
  live,
  lost,
}

/// Second-by-second heart rate from a Bluetooth sensor: permissions, scanning,
/// connecting, reconnecting to the last device and a 2-minute rolling history.
class LiveHeart extends ChangeNotifier {
  LiveHeart({
    required HeartSensor real,
    HeartSensor? demo,
    this.retryDelay = const Duration(seconds: 5),
  }) : _real = real,
       _demo = demo ?? SimulatedHeartSensor();

  /// How long to wait before reconnecting after the sensor drops out.
  final Duration retryDelay;

  final HeartSensor _real, _demo;
  bool demoMode = false;
  HeartSensor get sensor => demoMode ? _demo : _real;

  LivePhase phase = LivePhase.idle;
  final List<SensorDevice> found = [];
  SensorDevice? device;
  HrReading? latest;
  final List<HrReading> history = [];
  final List<double> _rr = [];
  double? hrv;
  int? sessionMin, sessionMax;
  double _sum = 0;
  int _count = 0;
  int? get sessionAvg => _count == 0 ? null : (_sum / _count).round();

  StreamSubscription<SensorDevice>? _scan;
  StreamSubscription<LinkState>? _link;
  StreamSubscription<HrReading>? _data;
  Timer? _scanStop, _retry;
  bool _wanted = false;

  bool get isLive =>
      phase == LivePhase.live &&
      latest != null &&
      DateTime.now().difference(latest!.at) < const Duration(seconds: 10);

  void setDemo(bool v) {
    if (v == demoMode) return;
    stop();
    demoMode = v;
  }

  Future<bool> _ensureReady() async {
    if (!sensor.available) {
      _set(LivePhase.unsupported);
      return false;
    }
    var s = await sensor
        .status()
        .firstWhere(
          (s) => s != SensorStatus.unknown,
          orElse: () => SensorStatus.unknown,
        )
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => SensorStatus.unknown,
        );
    if (s == SensorStatus.unauthorized || s == SensorStatus.unknown) {
      if (!await sensor.requestPermission()) {
        _set(LivePhase.needsPermission);
        return false;
      }
      s = await sensor
          .status()
          .firstWhere((s) => s != SensorStatus.unknown)
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => SensorStatus.ready,
          );
    }
    switch (s) {
      case SensorStatus.bluetoothOff:
        _set(LivePhase.bluetoothOff);
        return false;
      case SensorStatus.locationOff:
        _set(LivePhase.locationOff);
        return false;
      case SensorStatus.unsupported:
        _set(LivePhase.unsupported);
        return false;
      case SensorStatus.unauthorized:
        _set(LivePhase.needsPermission);
        return false;
      default:
        return true;
    }
  }

  /// Looks for nearby sensors for up to 15 seconds.
  Future<void> startScan() async {
    await _scan?.cancel();
    found.clear();
    if (!await _ensureReady()) return;
    _set(LivePhase.scanning);
    _scan = sensor.scan().listen((d) {
      final i = found.indexWhere((x) => x.id == d.id);
      i < 0 ? found.add(d) : found[i] = d;
      found.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
      notifyListeners();
    }, onError: (_) => _set(LivePhase.idle));
    _scanStop?.cancel();
    _scanStop = Timer(const Duration(seconds: 15), stopScan);
  }

  void stopScan() {
    _scan?.cancel();
    _scan = null;
    _scanStop?.cancel();
    if (phase == LivePhase.scanning) _set(LivePhase.idle);
  }

  Future<void> connect(SensorDevice d) async {
    stopScan();
    await _disconnectStreams();
    device = d;
    _wanted = true;
    history.clear();
    _rr.clear();
    hrv = null;
    sessionMin = sessionMax = null;
    _sum = 0;
    _count = 0;
    latest = null;
    _set(LivePhase.connecting);
    if (!demoMode) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('ble.id', d.id);
        await p.setString('ble.name', d.name);
      } catch (_) {}
    }
    _link = sensor.connect(d.id).listen((s) {
      if (s == LinkState.connected) {
        _subscribe(d.id);
      } else if (s == LinkState.disconnected) {
        _lost();
      }
    }, onError: (_) => _lost());
  }

  /// Reconnects to the sensor used last time, if there is one.
  Future<void> reconnectLast() async {
    if (demoMode || phase != LivePhase.idle) return;
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString('ble.id');
      if (id == null || !await _ensureReady()) return;
      await connect(
        SensorDevice(
          id: id,
          name: p.getString('ble.name') ?? 'Heart rate sensor',
        ),
      );
    } catch (_) {}
  }

  void _subscribe(String id) {
    _data?.cancel();
    _data = sensor.readings(id).listen(_add, onError: (_) => _lost());
  }

  void _add(HrReading r) {
    latest = r;
    history.add(r);
    final cutoff = r.at.subtract(const Duration(minutes: 2));
    history.removeWhere((x) => x.at.isBefore(cutoff));
    _rr.addAll(r.rrMs);
    if (_rr.length > 120) _rr.removeRange(0, _rr.length - 120);
    hrv = rmssd(_rr);
    sessionMin = sessionMin == null || r.bpm < sessionMin! ? r.bpm : sessionMin;
    sessionMax = sessionMax == null || r.bpm > sessionMax! ? r.bpm : sessionMax;
    _sum += r.bpm;
    _count++;
    phase = LivePhase.live;
    notifyListeners();
  }

  void _lost() {
    _data?.cancel();
    if (!_wanted) return;
    _set(LivePhase.lost);
    // Keep trying while the user still wants the connection.
    _retry?.cancel();
    _retry = Timer(retryDelay, () {
      if (_wanted && device != null) connect(device!);
    });
  }

  Future<void> _disconnectStreams() async {
    // Do not wait for the sensor to confirm: a stalled radio must never block Disconnect.
    _retry?.cancel();
    unawaited(_data?.cancel());
    unawaited(_link?.cancel());
    _data = null;
    _link = null;
  }

  Future<void> stop({bool forget = false}) async {
    _wanted = false;
    stopScan();
    await _disconnectStreams();
    latest = null;
    if (forget && !demoMode) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove('ble.id');
        await p.remove('ble.name');
      } catch (_) {}
    }
    _set(LivePhase.idle);
  }

  void _set(LivePhase p) {
    phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _wanted = false;
    _scan?.cancel();
    _link?.cancel();
    _data?.cancel();
    _scanStop?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}

class LiveScope extends InheritedNotifier<LiveHeart> {
  const LiveScope({super.key, required LiveHeart live, required super.child})
    : super(notifier: live);
  static LiveHeart of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveScope>()!.notifier!;
  static LiveHeart read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LiveScope>()!.notifier!;
}
