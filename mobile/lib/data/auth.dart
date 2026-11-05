import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

/// Native Google Sign-In (Android Credential Manager / iOS GoogleSignIn SDK).
/// The access token stays on the device and is only sent to Google.
class GoogleAuthService implements AuthService {
  // The web OAuth client ID acts as the "server client ID" that Android requires.
  // Client IDs are public; never put a client secret in the app.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '269270971211-d1rkpnadf0ievfl94e534tq1tqgoucng.apps.googleusercontent.com',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  final _g = GoogleSignIn.instance;
  Future<void>? _init;
  GoogleSignInAccount? _account;
  String? _token;
  DateTime _tokenAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _ready() => _init ??= _g.initialize(
    serverClientId: defaultTargetPlatform == TargetPlatform.android
        ? _serverClientId
        : null,
    clientId:
        defaultTargetPlatform == TargetPlatform.iOS && _iosClientId.isNotEmpty
        ? _iosClientId
        : null,
  );

  AppUser _user(GoogleSignInAccount a) => AppUser(
    email: a.email,
    name: a.displayName ?? a.email,
    photoUrl: a.photoUrl,
  );

  @override
  Future<AppUser?> restore() async {
    if (!supported) return null;
    await _ready();
    try {
      final a = await _g.attemptLightweightAuthentication();
      if (a == null) return null;
      final authz = await a.authorizationClient.authorizationForScopes(
        healthScopes,
      );
      if (authz == null) return null;
      _account = a;
      _setToken(authz.accessToken);
      return _user(a);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> signIn() async {
    await _ready();
    try {
      final a = await _g.authenticate(scopeHint: healthScopes);
      final authz =
          await a.authorizationClient.authorizationForScopes(healthScopes) ??
          await a.authorizationClient.authorizeScopes(healthScopes);
      _account = a;
      _setToken(authz.accessToken);
      return _user(a);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SignInCancelled();
      rethrow;
    }
  }

  void _setToken(String t) {
    _token = t;
    _tokenAt = DateTime.now();
  }

  @override
  Future<String> accessToken() async {
    // Google access tokens last about an hour; renew silently a little before that.
    if (_token != null &&
        DateTime.now().difference(_tokenAt) < const Duration(minutes: 50)) {
      return _token!;
    }
    await refreshToken();
    return _token!;
  }

  @override
  Future<void> refreshToken() async {
    final a = _account;
    if (a == null) throw const AuthExpiredError();
    if (_token != null) {
      await a.authorizationClient.clearAuthorizationToken(accessToken: _token!);
    }
    final authz = await a.authorizationClient.authorizationForScopes(
      healthScopes,
    );
    if (authz == null) throw const AuthExpiredError();
    _setToken(authz.accessToken);
  }

  @override
  Future<void> signOut() async {
    await _ready();
    _token = null;
    _account = null;
    // disconnect() also removes the app's access to Google Health data.
    try {
      await _g.disconnect();
    } catch (_) {
      await _g.signOut();
    }
  }
}
