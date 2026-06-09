import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';

/// The result of a successful authentication.
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

/// Drives the OIDC Authorization Code + PKCE flow against Keycloak on web
/// (AGENTS.md §1 `core/services`). Uses its own bare Dio so it never carries
/// the BFF bearer token to Keycloak.
class AuthService {
  AuthService() : _dio = Dio();

  final Dio _dio;

  static const String _kVerifier = 'oidc_code_verifier';
  static const String _kState = 'oidc_state';
  static const String _kAccessToken = 'oidc_access_token';
  static const String _kExpiry = 'oidc_expiry_ms';

  Uri get _authEndpoint =>
      Uri.parse('${AppConfig.oidcIssuer}/protocol/openid-connect/auth');
  Uri get _tokenEndpoint =>
      Uri.parse('${AppConfig.oidcIssuer}/protocol/openid-connect/token');

  /// On startup: finish a redirect callback if present, else restore a stored
  /// unexpired session, else return null (unauthenticated).
  Future<AuthTokens?> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? code = Uri.base.queryParameters['code'];
    final String? returnedState = Uri.base.queryParameters['state'];

    if (code != null) {
      final String? verifier = prefs.getString(_kVerifier);
      final String? savedState = prefs.getString(_kState);
      if (verifier != null && returnedState == savedState) {
        try {
          return await _exchangeCode(code, verifier, prefs);
        } catch (_) {
          // Authorization code already used/expired — fall back to any stored
          // session instead of erroring.
        }
      }
    }
    return _restore(prefs);
  }

  /// Redirects the browser to Keycloak to begin login.
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

  /// Clears the stored session.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kExpiry);
    await prefs.remove(_kVerifier);
    await prefs.remove(_kState);
  }

  Future<AuthTokens?> _restore(SharedPreferences prefs) async {
    final String? token = prefs.getString(_kAccessToken);
    final int expiry = prefs.getInt(_kExpiry) ?? 0;
    if (token == null ||
        DateTime.now().millisecondsSinceEpoch >= expiry) {
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
