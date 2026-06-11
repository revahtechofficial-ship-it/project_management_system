import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/auth_user.dart';
import '../constants/app_config.dart';

/// A live, authenticated session: the app JWT plus the user it belongs to.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Thrown for auth API failures; [message] is safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the BFF's custom auth API (`/api/v1/auth/*`) and persists the
/// session in shared_preferences (AGENTS.md §1 `core/services`).
class AuthService {
  AuthService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          contentType: 'application/json',
        ));

  final Dio _dio;

  static const String _kToken = 'auth_token';
  static const String _kUser = 'auth_user';

  /// Restores a stored session, or null if none.
  Future<AuthSession?> restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_kToken);
    final String? userJson = prefs.getString(_kUser);
    if (token == null || userJson == null) {
      return null;
    }
    return AuthSession(
      token: token,
      user: AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
    );
  }

  /// Creates an account; the user must then verify their email.
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _post('/api/v1/auth/register', <String, dynamic>{
      'email': email,
      'password': password,
      'full_name': fullName,
    });
  }

  /// Confirms a signup OTP; the user must then sign in.
  Future<void> verifyEmail({required String email, required String code}) async {
    await _post('/api/v1/auth/verify-email',
        <String, dynamic>{'email': email, 'code': code});
  }

  /// Signs in and persists the returned session.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/api/v1/auth/login',
      <String, dynamic>{'email': email, 'password': password},
    );
    final String token = data['token'] as String;
    final AuthUser user =
        AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    return AuthSession(token: token, user: user);
  }

  /// Requests a password-reset OTP.
  Future<void> forgotPassword(String email) async {
    await _post('/api/v1/auth/forgot-password', <String, dynamic>{'email': email});
  }

  /// Sets a new password using a reset OTP; the user must then sign in.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post('/api/v1/auth/reset-password', <String, dynamic>{
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  /// Re-issues a signup or reset OTP.
  Future<void> resendOtp({required String email, required String purpose}) async {
    await _post('/api/v1/auth/resend-otp',
        <String, dynamic>{'email': email, 'purpose': purpose});
  }

  /// Clears the stored session.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final Response<Map<String, dynamic>> res =
          await _dio.post<Map<String, dynamic>>(path, data: body);
      return res.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw AuthException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final dynamic data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Is the backend running?';
    }
    return 'Something went wrong. Please try again.';
  }
}
