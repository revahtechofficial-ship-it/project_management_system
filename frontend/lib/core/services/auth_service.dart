import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';

/// The result of a successful Keycloak authentication.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.username,
    required this.email,
  });

  final String accessToken;
  final String username;
  final String email;
}

/// Outcome of [AuthService.initialize].
class InitResult {
  const InitResult({
    this.tokens,
    this.vikunjaReady = false,
    this.needsVikunjaLogin = false,
  });

  final AuthTokens? tokens;
  final bool vikunjaReady;
  final bool needsVikunjaLogin;
}

/// Drives two OIDC flows against Keycloak on web (AGENTS.md §1 `core/services`):
///   1. `revahms-web` (PKCE) -> a Keycloak token for the BFF.
///   2. `vikunja` -> a code the BFF swaps (server-side) for a Vikunja JWT.
/// Uses its own bare Dio so it never carries the BFF bearer token to Keycloak.
class AuthService {
  AuthService() : _dio = Dio();

  final Dio _dio;

  static const String _vikunjaClientId = 'vikunja';

  static const String _kVerifier = 'oidc_code_verifier';
  static const String _kState = 'oidc_state';
  static const String _kAccessToken = 'oidc_access_token';
  static const String _kExpiry = 'oidc_expiry_ms';
  static const String _kVikunjaState = 'oidc_vikunja_state';
  static const String _kVikunjaReady = 'vikunja_ready';
  static const String _kVikunjaAttempted = 'vikunja_attempted';

  Uri get _authEndpoint =>
      Uri.parse('${AppConfig.oidcIssuer}/protocol/openid-connect/auth');
  Uri get _tokenEndpoint =>
      Uri.parse('${AppConfig.oidcIssuer}/protocol/openid-connect/token');

  /// On startup: handle whichever redirect callback is present (Keycloak login
  /// or the Vikunja-session handshake), else restore a stored session.
  Future<InitResult> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? code = Uri.base.queryParameters['code'];
    final String? returnedState = Uri.base.queryParameters['state'];

    // (2) Vikunja handshake callback?
    if (code != null && returnedState == prefs.getString(_kVikunjaState)) {
      await prefs.remove(_kVikunjaState);
      final AuthTokens? tokens = await _restore(prefs);
      final bool ready = tokens != null && await _establishVikunja(code, prefs);
      return InitResult(tokens: tokens, vikunjaReady: ready);
    }

    // (1) Keycloak login callback?
    if (code != null && returnedState == prefs.getString(_kState)) {
      final String? verifier = prefs.getString(_kVerifier);
      if (verifier != null) {
        try {
          final AuthTokens tokens = await _exchangeCode(code, verifier, prefs);
          return _afterAuth(prefs, tokens);
        } catch (_) {
          // Code already used/expired — fall through to a stored session.
        }
      }
    }

    final AuthTokens? tokens = await _restore(prefs);
    if (tokens == null) {
      return const InitResult();
    }
    return _afterAuth(prefs, tokens);
  }

  InitResult _afterAuth(SharedPreferences prefs, AuthTokens tokens) {
    final bool ready = prefs.getBool(_kVikunjaReady) ?? false;
    final bool attempted = prefs.getBool(_kVikunjaAttempted) ?? false;
    return InitResult(
      tokens: tokens,
      vikunjaReady: ready,
      needsVikunjaLogin: !ready && !attempted,
    );
  }

  /// Redirects the browser to Keycloak to begin the primary (BFF) login.
  Future<void> beginLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String verifier = _randomString(64);
    final String state = _randomString(24);
    await prefs.setString(_kVerifier, verifier);
    await prefs.setString(_kState, state);

    final String challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');

    final Uri url = _authEndpoint.replace(queryParameters: <String, String>{
      'response_type': 'code',
      'client_id': AppConfig.oidcClientId,
      'redirect_uri': AppConfig.oidcRedirectUri,
      'scope': 'openid profile email',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  /// Redirects to Keycloak for the `vikunja` client (silent SSO — the session
  /// from [beginLogin] is reused) to obtain a code for the BFF to exchange.
  Future<void> beginVikunjaLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String state = _randomString(24);
    await prefs.setString(_kVikunjaState, state);
    await prefs.setBool(_kVikunjaAttempted, true);

    final Uri url = _authEndpoint.replace(queryParameters: <String, String>{
      'response_type': 'code',
      'client_id': _vikunjaClientId,
      'redirect_uri': AppConfig.oidcRedirectUri,
      'scope': 'openid profile email',
      'state': state,
    });
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  /// Clears the stored session.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String k in <String>[
      _kAccessToken,
      _kExpiry,
      _kVerifier,
      _kState,
      _kVikunjaState,
      _kVikunjaReady,
      _kVikunjaAttempted,
    ]) {
      await prefs.remove(k);
    }
  }

  Future<bool> _establishVikunja(String code, SharedPreferences prefs) async {
    final String? accessToken = prefs.getString(_kAccessToken);
    if (accessToken == null) {
      return false;
    }
    try {
      await _dio.post<void>(
        '${AppConfig.apiBaseUrl}/api/v1/vikunja/session',
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        ),
        data: <String, String>{
          'code': code,
          'redirect_uri': AppConfig.oidcRedirectUri,
        },
      );
      await prefs.setBool(_kVikunjaReady, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AuthTokens?> _restore(SharedPreferences prefs) async {
    final String? token = prefs.getString(_kAccessToken);
    final int expiry = prefs.getInt(_kExpiry) ?? 0;
    if (token == null || DateTime.now().millisecondsSinceEpoch >= expiry) {
      return null;
    }
    return _tokensFromAccess(token);
  }

  Future<AuthTokens> _exchangeCode(
    String code,
    String verifier,
    SharedPreferences prefs,
  ) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      _tokenEndpoint.toString(),
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: <String, String>{
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': AppConfig.oidcRedirectUri,
        'client_id': AppConfig.oidcClientId,
        'code_verifier': verifier,
      },
    );
    final Map<String, dynamic> body = res.data ?? <String, dynamic>{};
    final String accessToken = body['access_token'] as String;
    final int expiresIn = (body['expires_in'] as num?)?.toInt() ?? 300;
    final int expiry = DateTime.now()
        .add(Duration(seconds: expiresIn))
        .millisecondsSinceEpoch;
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setInt(_kExpiry, expiry);
    await prefs.remove(_kVerifier);
    await prefs.remove(_kState);
    return _tokensFromAccess(accessToken);
  }

  AuthTokens _tokensFromAccess(String accessToken) {
    final Map<String, dynamic> claims = _decodeJwt(accessToken);
    return AuthTokens(
      accessToken: accessToken,
      username: claims['preferred_username'] as String? ?? '',
      email: claims['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return <String, dynamic>{};
    }
    String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    switch (payload.length % 4) {
      case 2:
        payload += '==';
      case 3:
        payload += '=';
    }
    return jsonDecode(utf8.decode(base64.decode(payload)))
        as Map<String, dynamic>;
  }

  String _randomString(int length) {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final Random rnd = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }
}
