import 'package:basivo_fit/data/auth.dart';
import 'package:basivo_fit/data/health_api.dart';
import 'package:basivo_fit/data/heart_sensor.dart';
import 'package:basivo_fit/state/live_heart.dart';
import 'package:basivo_fit/data/models.dart';
import 'package:basivo_fit/main.dart';
import 'package:basivo_fit/state/health_store.dart';
import 'package:basivo_fit/state/settings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:basivo_fit/ui/screens/live.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth implements AuthService {
  FakeAuth({this.user});
  AppUser? user;
  int signIns = 0, signOuts = 0;
  @override
  bool get supported => true;
  @override
  Future<AppUser?> restore() async => user;
  @override
  Future<AppUser> signIn() async {
    signIns++;
    return user = const AppUser(email: 'tester@example.com', name: 'Test User');
  }

  @override
  Future<String> accessToken() async => 'token';
  @override
  Future<void> refreshToken() async {}
  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
  }
}

/// Google replies with nothing at all: an account with no tracker.
HealthApi emptyApi(Future<String> Function() t) => HealthApi(
  token: t,
  client: MockClient((_) async => http.Response('{}', 200)),
);

Future<void> pumpApp(
  WidgetTester tester,
  HealthStore store, {
  bool reduceMotion = true,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final theme = ThemeController();
  await store.start();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: BasivoFitApp(
        store: store,
        theme: theme,
        live: LiveHeart(
          real: SimulatedHeartSensor(),
          demo: SimulatedHeartSensor(
            interval: const Duration(milliseconds: 200),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> tapDemo(WidgetTester tester) async {
  // The login screen is a single fixed screen: the demo button is always visible.
  expect(find.byType(Scrollable), findsNothing);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('Try the demo'));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync()),
        ),
      );
    }
    await l.load();
  }

  await load('Manrope', [
    for (final w in [400, 500, 600, 700, 800]) 'Manrope-$w.ttf',
  ]);
  await load('SpaceGrotesk', [
    for (final w in [400, 500, 600, 700]) 'SpaceGrotesk-$w.ttf',
  ]);
}

void main() {
  setUpAll(loadFonts);
  testWidgets('login screen offers Google sign-in and the demo', (
    tester,
  ) async {
    await pumpApp(tester, HealthStore(auth: FakeAuth()));
    expect(find.text('Basivo Fit'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Try the demo'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'login fits one screen without scrolling at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final store = HealthStore(auth: FakeAuth());
        await pumpApp(tester, store, size: size);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        for (final t in ['Sign in with Google', 'Try the demo', 'Privacy']) {
          final r = tester.getRect(find.text(t));
          expect(r.bottom <= size.height, isTrue, reason: '$t is on screen');
        }
      },
    );
  }

  for (final size in const [Size(390, 844), Size(320, 640), Size(820, 1180)]) {
    testWidgets(
      'demo: every tab renders without overflow at ${size.width.toInt()}px',
      (tester) async {
        final store = HealthStore(auth: FakeAuth());
        await pumpApp(tester, store, size: size);
        await tapDemo(tester);
        await settle(tester);
        expect(find.text('Demo data'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Body and vitals'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);

        for (final (tab, expectText) in [
          ('Heart tab', 'Time in heart-rate zones'),
          ('Sleep tab', 'Sleep quality'),
          ('Activity tab', 'Steps by hour'),
          ('Profile tab', 'Appearance'),
        ]) {
          await tester.tap(find.bySemanticsLabel(tab));
          await settle(tester);
          await tester.scrollUntilVisible(
            find.text(expectText),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(expectText), findsWidgets, reason: tab);
        }
        expect(tester.takeException(), isNull);
        store.dispose();
      },
    );
  }

  testWidgets('large system text (150%) does not break any tab', (
    tester,
  ) async {
    final store = HealthStore(auth: FakeAuth());
    await pumpApp(tester, store, textScale: 1.5);
    await tapDemo(tester);
    await settle(tester);
    for (final tab in [
      'Heart tab',
      'Sleep tab',
      'Activity tab',
      'Profile tab',
      'Today tab',
    ]) {
      await tester.tap(find.bySemanticsLabel(tab));
      await settle(tester);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await settle(tester);
      }
    }
    expect(tester.takeException(), isNull);
    store.dispose();
  });

  testWidgets(
    'demo: Bluetooth live heart rate finds a sensor and shows every beat',
    (tester) async {
      final store = HealthStore(auth: FakeAuth());
      await pumpApp(tester, store);
      await tapDemo(tester);
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Heart tab'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Find a sensor'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Find a sensor'));
      await settle(tester);
      expect(find.text('Demo chest strap'), findsOneWidget);
      await tester.tap(find.text('Demo chest strap'));
      await settle(tester);
      await settle(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.textContaining('zone'), findsWidgets);
      expect(find.text('Lowest'), findsOneWidget);
      // Bring the button to the middle of the screen, clear of the tab bar.
      await Scrollable.ensureVisible(
        tester.element(find.text('Disconnect')),
        alignment: 0.5,
      );
      await settle(tester);
      await tester.tap(find.text('Disconnect'));
      await settle(tester);
      expect(find.text('Find a sensor'), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );

  testWidgets('heart: week view and day navigation', (tester) async {
    final store = HealthStore(auth: FakeAuth());
    await pumpApp(tester, store);
    await tapDemo(tester);
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Heart tab'));
    await settle(tester);
    expect(find.text('Today'), findsWidgets);
    await tester.tap(find.byTooltip('Previous day'));
    await settle(tester);
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('Last 7 days'), findsOneWidget);
    store.dispose();
  });

  testWidgets(
    'animations run with motion on (no exceptions, theme reveal works)',
    (tester) async {
      final store = HealthStore(auth: FakeAuth());
      await pumpApp(tester, store, reduceMotion: false);
      await tapDemo(tester);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byTooltip('Switch to dark mode').first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('Switch to light mode'), findsWidgets);
      await tester.tap(find.byTooltip('Switch to light mode').first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('Switch to dark mode'), findsWidgets);
      expect(tester.takeException(), isNull);
      store.dispose();
    },
  );

  testWidgets(
    'signed-in account without a tracker sees "No device connected" and can switch',
    (tester) async {
      final auth = FakeAuth(
        user: const AppUser(email: 'nofitbit@example.com', name: 'No Fitbit'),
      );
      final store = HealthStore(auth: auth, apiFactory: emptyApi);
      await pumpApp(tester, store);
      await settle(tester);
      expect(find.text('No device connected'), findsOneWidget);
      expect(find.textContaining('nofitbit@example.com'), findsOneWidget);
      expect(find.text('Sign in with another account'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await settle(tester);
      expect(auth.signOuts, 1);
      expect(find.text('Sign in with Google'), findsOneWidget);
      store.dispose();
    },
  );

  testWidgets('expired sign-in returns to the login screen with a message', (
    tester,
  ) async {
    final store = HealthStore(
      auth: FakeAuth(
        user: const AppUser(email: 'a@b.c', name: 'A'),
      ),
      apiFactory: (t) => HealthApi(
        token: t,
        client: MockClient((_) async => http.Response('{}', 401)),
      ),
    );
    await pumpApp(tester, store);
    await settle(tester);
    expect(
      find.textContaining('Google sign-in lasts about an hour'),
      findsOneWidget,
    );
    store.dispose();
  });

  test('zone limits classify like the Google Health app', () {
    expect(ZoneLimits.fallback.zoneOf(122), Zone.moderate);
    expect(ZoneLimits.fallback.zoneOf(150), Zone.vigorous);
    expect(ZoneLimits.fallback.zoneOf(90), Zone.light);
  });

  test('sharing help matches the picked device', () {
    expect(sharingSteps('Fitbit Air'), contains('Google Health'));
    expect(sharingSteps('Amazfit T-Rex Pro'), contains('Zepp'));
    expect(sharingSteps('Polar H10'), contains('broadcast'));
  });
}
