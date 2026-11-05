import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'health_api.dart';

class AppUser {
  const AppUser({required this.email, required this.name, this.photoUrl});
  final String email, name;
  final String? photoUrl;
}

/// Sign-in contract so the UI and tests do not depend on a real Google account.
abstract class AuthService {
  bool get supported;
  Future<AppUser?> restore();
  Future<AppUser> signIn();
  Future<String> accessToken();
  Future<void> refreshToken();
  Future<void> signOut();
}

const healthScopes = [
  'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
  'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
  'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
  'https://www.googleapis.com/auth/googlehealth.settings.readonly',
];

class SignInCancelled implements Exception {}

class MissingPermission implements Exception {}

/// Google sign-in in the phone's browser (Custom Tab on Android, ASWebAuthenticationSession on iPhone),
/// using the same Web OAuth client as the web app, so no extra Google Cloud setup is needed.
///
/// Google returns to the web app's address (already allowed on the client); the web app sees the
/// `app.` state and hands the result straight back to this app through the basivofit:// link.
/// The access token stays on the phone and is only sent to Google.
class BrowserOAuthService implements AuthService {
  BrowserOAuthService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;

  static const clientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '269270971211-d1rkpnadf0ievfl94e534tq1tqgoucng.apps.googleusercontent.com',
  );
  static const redirectUri = String.fromEnvironment(
    'OAUTH_REDIRECT',
    defaultValue: 'https://pulsefolio-jade.vercel.app/',
  );
  static const callbackScheme = 'basivofit';
  static const _key = 'pf.session';

  String? _token;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<AppUser?> restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final exp = DateTime.fromMillisecondsSinceEpoch(j['exp'] as int);
      if (exp.difference(DateTime.now()) < const Duration(minutes: 1)) {
        return null;
      }
      _token = j['token'] as String;
      _expires = exp;
      final u = j['user'] as Map<String, dynamic>;
      return AppUser(
        email: u['email'] as String,
        name: u['name'] as String,
        photoUrl: u['photo'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signIn() async {
    final rnd = Random.secure();
    final state =
        'app.${List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'token',
      'scope': ['openid', 'email', 'profile', ...healthScopes].join(' '),
      'include_granted_scopes': 'true',
      'prompt': 'select_account',
      'state': state,
    }).toString();
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw SignInCancelled();
      rethrow;
    }
    final p = parseCallback(result);
    if (p['state'] != state) throw StateError('Sign-in could not be verified.');
    if (p['error'] == 'access_denied') throw SignInCancelled();
    final token = p['access_token'];
    if (token == null || token.isEmpty) {
      throw StateError(p['error'] ?? 'No token');
    }
    final granted = (p['scope'] ?? '').split(' ');
    if (!healthScopes.every(granted.contains)) throw MissingPermission();
    _token = token;
    _expires = DateTime.now().add(
      Duration(seconds: int.tryParse(p['expires_in'] ?? '') ?? 3600),
    );
    final user = await _userInfo(token);
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'token': token,
          'exp': _expires.millisecondsSinceEpoch,
          'user': {
            'email': user.email,
            'name': user.name,
            'photo': user.photoUrl,
          },
        }),
      );
    } catch (_) {}
    return user;
  }

  /// Reads `basivofit://auth#access_token=...&state=...` (fragment or query).
  static Map<String, String> parseCallback(String url) {
    final u = Uri.parse(url);
    final raw = u.fragment.isNotEmpty ? u.fragment : u.query;
    return Uri.splitQueryString(raw);
  }

  Future<AppUser> _userInfo(String token) async {
    try {
      final r = await _client.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final u = jsonDecode(r.body) as Map<String, dynamic>;
        final email = (u['email'] ?? '') as String;
        return AppUser(
          email: email,
          name: (u['name'] ?? email) as String,
          photoUrl: u['picture'] as String?,
        );
      }
    } catch (_) {}
    return const AppUser(email: '', name: 'Signed in');
  }

  @override
  Future<String> accessToken() async {
    if (_token != null &&
        _expires.difference(DateTime.now()) > const Duration(minutes: 1)) {
      return _token!;
    }
    throw const AuthExpiredError();
  }

  // Browser tokens last about an hour and cannot be renewed silently; the user signs in again (one tap).
  @override
  Future<void> refreshToken() async => throw const AuthExpiredError();

  @override
  Future<void> signOut() async {
    final t = _token;
    _token = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
    if (t != null) {
      try {
        await _client.post(
          Uri.parse('https://oauth2.googleapis.com/revoke'),
          body: {'token': t},
        );
      } catch (_) {}
    }
  }
}
