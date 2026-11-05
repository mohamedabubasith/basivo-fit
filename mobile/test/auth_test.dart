import 'dart:convert';
import 'package:basivo_fit/data/auth.dart';
import 'package:basivo_fit/data/health_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads the token from the basivofit:// callback', () {
    final p = BrowserOAuthService.parseCallback(
      'basivofit://auth#access_token=ya29.abc&expires_in=3599&state=app.00ff&scope=a%20b',
    );
    expect(p['access_token'], 'ya29.abc');
    expect(p['expires_in'], '3599');
    expect(p['state'], 'app.00ff');
    expect(p['scope'], 'a b');
    expect(
      BrowserOAuthService.parseCallback(
        'basivofit://auth?error=access_denied&state=x',
      )['error'],
      'access_denied',
    );
  });

  test(
    'restores a saved session and treats an expired one as signed out',
    () async {
      final exp = DateTime.now()
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'pf.session': jsonEncode({
          'token': 't1',
          'exp': exp,
          'user': {'email': 'a@b.c', 'name': 'A', 'photo': null},
        }),
      });
      final auth = BrowserOAuthService();
      final u = await auth.restore();
      expect(u!.email, 'a@b.c');
      expect(await auth.accessToken(), 't1');

      SharedPreferences.setMockInitialValues({
        'pf.session': jsonEncode({
          'token': 't2',
          'exp': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
          'user': {'email': 'a', 'name': 'a'},
        }),
      });
      final auth2 = BrowserOAuthService();
      expect(await auth2.restore(), isNull);
      expect(auth2.accessToken, throwsA(isA<AuthExpiredError>()));
    },
  );

  test(
    'sign out forgets the session and revokes the token with Google',
    () async {
      SharedPreferences.setMockInitialValues({
        'pf.session': jsonEncode({
          'token': 'tok',
          'exp': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'user': {'email': 'a', 'name': 'a'},
        }),
      });
      final calls = <http.Request>[];
      final auth = BrowserOAuthService(
        client: MockClient((r) async {
          calls.add(r);
          return http.Response('', 200);
        }),
      );
      await auth.restore();
      await auth.signOut();
      expect(
        (await SharedPreferences.getInstance()).getString('pf.session'),
        isNull,
      );
      expect(
        calls.single.url.toString(),
        'https://oauth2.googleapis.com/revoke',
      );
      expect(calls.single.bodyFields['token'], 'tok');
      expect(auth.accessToken, throwsA(isA<AuthExpiredError>()));
    },
  );
}
