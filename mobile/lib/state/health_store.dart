import 'package:flutter/services.dart' show PlatformException;
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/auth.dart';
import '../data/demo.dart';
import '../data/health_api.dart';
import '../data/models.dart';

enum Phase { loading, login, app }

enum Problem { none, noDevice, permission, error }

/// App-wide state: who is signed in, the latest health data, and what went wrong.
class HealthStore extends ChangeNotifier with WidgetsBindingObserver {
  HealthStore({
    required this.auth,
    HealthApi Function(Future<String> Function())? apiFactory,
  }) : _apiFactory = apiFactory ?? ((t) => HealthApi(token: t));

  final AuthService auth;
  final HealthApi Function(Future<String> Function()) _apiFactory;
  late final HealthApi api = _apiFactory(_token);

  Phase phase = Phase.loading;
  bool demo = false;
  AppUser? user;
  Health? health;
  Problem problem = Problem.none;
  String message = '';
  String? loginMessage;
  bool loading = false;
  Timer? _refresh, _live;
  bool _busy = false;

  Future<String> _token() => auth.accessToken();

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    final u = await auth.restore();
    if (u != null) {
      _enter(u);
    } else {
      phase = Phase.login;
      notifyListeners();
    }
  }

  void _enter(AppUser u) {
    user = u;
    demo = false;
    phase = Phase.app;
    health = null;
    notifyListeners();
    reload();
    _startTimers();
  }

  void startDemo() {
    demo = true;
    user = null;
    problem = Problem.none;
    health = demoHealth();
    phase = Phase.app;
    _stopTimers();
    notifyListeners();
  }

  void exitDemo() {
    demo = false;
    health = null;
    phase = Phase.login;
    notifyListeners();
  }

  static String _describe(Object e) {
    if (e is StateError) return e.message;
    if (e is PlatformException) return '${e.code} ${e.message ?? ''}'.trim();
    final t = e.toString();
    return t.length > 160 ? '${t.substring(0, 160)}…' : t;
  }

  Future<void> signIn({bool switching = false}) async {
    loginMessage = null;
    try {
      if (switching) await auth.signOut();
      _enter(await auth.signIn());
    } on SignInCancelled {
      if (switching) _toLogin();
    } on MissingPermission {
      _toLogin(
        'Basivo Fit needs all the health permissions. Please sign in again and tick every box.',
      );
    } catch (e) {
      _toLogin('Sign-in did not finish: ${_describe(e)}');
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
    _toLogin();
  }

  void _toLogin([String? msg]) {
    _stopTimers();
    user = null;
    health = null;
    problem = Problem.none;
    loginMessage = msg;
    phase = Phase.login;
    notifyListeners();
  }

  Future<void> reload() async {
    if (demo) {
      health = demoHealth();
      notifyListeners();
      return;
    }
    if (_busy) return;
    _busy = true;
    loading = true;
    notifyListeners();
    try {
      health = await _withRetry(api.fetchHealth);
      problem = Problem.none;
      message = '';
    } on AuthExpiredError {
      await auth.signOut();
      _toLogin(
        'Your Google sign-in lasts about an hour. Tap Sign in with Google to continue.',
      );
    } on NoDeviceError catch (e) {
      problem = Problem.noDevice;
      message = e.message;
    } on PermissionError catch (e) {
      problem = Problem.permission;
      message = e.message;
    } catch (_) {
      problem = Problem.error;
      message =
          'Could not load your health data. Check your internet and try again.';
    } finally {
      _busy = false;
      loading = false;
      notifyListeners();
    }
  }

  /// One silent token refresh on a 401 before giving up.
  Future<T> _withRetry<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on AuthExpiredError {
      await auth.refreshToken();
      return f();
    }
  }

  Future<void> _pollLive() async {
    if (demo || health == null || phase != Phase.app) return;
    try {
      final n = await api.latestHeartRate();
      final cur = health!.now;
      if (n != null && (cur == null || !n.at.isBefore(cur.at))) {
        health = health!.withNow(n);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startTimers() {
    _stopTimers();
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) => reload());
    _live = Timer.periodic(const Duration(seconds: 20), (_) => _pollLive());
  }

  void _stopTimers() {
    _refresh?.cancel();
    _live?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (demo || phase != Phase.app) return;
    if (state == AppLifecycleState.resumed) {
      reload();
      _startTimers();
    } else if (state == AppLifecycleState.paused) {
      _stopTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }
}

/// Makes the store available to every screen.
class StoreScope extends InheritedNotifier<HealthStore> {
  const StoreScope({
    super.key,
    required HealthStore store,
    required super.child,
  }) : super(notifier: store);
  static HealthStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static HealthStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
