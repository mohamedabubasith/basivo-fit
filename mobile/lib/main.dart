import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/auth.dart';
import 'data/heart_sensor.dart';
import 'state/health_store.dart';
import 'state/live_heart.dart';
import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/reveal.dart';
import 'ui/screens/account.dart';
import 'ui/widgets/pulse.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final theme = ThemeController()..load();
  final store = HealthStore(auth: GoogleAuthService());
  // Web-only share links: ?demo=1 opens the demo, &tab=heart picks a tab, &theme=dark sets the theme.
  final q = kIsWeb ? Uri.base.queryParameters : const <String, String>{};
  store.start().then((_) {
    if (q['demo'] == '1') store.startDemo();
  });
  if (q['theme'] == 'dark' || q['theme'] == 'light') {
    theme.set(q['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }
  initialTab = const [
    'today',
    'heart',
    'sleep',
    'activity',
    'profile',
  ].indexOf(q['tab'] ?? 'today').clamp(0, 4);
  final live = LiveHeart(real: BleHeartSensor());
  runApp(BasivoFitApp(store: store, theme: theme, live: live));
}

class BasivoFitApp extends StatefulWidget {
  const BasivoFitApp({
    super.key,
    required this.store,
    required this.theme,
    required this.live,
  });
  final HealthStore store;
  final ThemeController theme;
  final LiveHeart live;
  @override
  State<BasivoFitApp> createState() => _BasivoFitAppState();
}

class _BasivoFitAppState extends State<BasivoFitApp> {
  HealthStore get store => widget.store;
  ThemeController get theme => widget.theme;
  Phase? _lastPhase;

  @override
  void initState() {
    super.initState();
    store.addListener(_sync);
    _sync();
  }

  // Demo mode uses the simulated sensor; signing in reconnects the last real sensor; signing out stops it.
  void _sync() {
    widget.live.setDemo(store.demo);
    if (store.phase != _lastPhase) {
      if (store.phase == Phase.app && !store.demo) widget.live.reconnectLast();
      if (store.phase == Phase.login) widget.live.stop();
      _lastPhase = store.phase;
    }
  }

  @override
  void dispose() {
    store.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeReveal(
      child: ListenableBuilder(
        listenable: theme,
        builder: (context, _) => MaterialApp(
          title: 'Basivo Fit',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeAnimationDuration: Motion.base,
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  (dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: Colors.transparent,
                      ),
              child: StoreScope(
                store: store,
                child: LiveScope(live: widget.live, child: child!),
              ),
            );
          },
          home: _Root(theme: theme),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.theme});
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final child = switch (s.phase) {
      Phase.loading => const _Splash(),
      Phase.login => LoginScreen(theme: theme),
      Phase.app => Shell(theme: theme),
    };
    return AnimatedSwitcher(
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      switchInCurve: Motion.ease,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(a),
          child: c,
        ),
      ),
      child: KeyedSubtree(key: ValueKey('${s.phase}-${s.demo}'), child: child),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.c.bg,
    body: Center(
      child: Semantics(
        label: 'Loading PulseFolio',
        child: ScaleTransition(
          scale: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 20),
            TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.97), weight: 20),
            TweenSequenceItem(tween: Tween(begin: 0.97, end: 1), weight: 20),
            TweenSequenceItem(tween: ConstantTween(1), weight: 40),
          ]).animate(_c),
          child: const AppLogo(size: 72),
        ),
      ),
    ),
  );
}
