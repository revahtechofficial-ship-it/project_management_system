import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

/// Shared Dio HTTP client, pointed at the backend base URL.
///
/// When SSO lands, attach the OIDC/JWT bearer token via an interceptor here so
/// every request is authenticated.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
    ),
  );

  // Example auth hook (disabled until SSO is wired):
  // dio.interceptors.add(
  //   InterceptorsWrapper(onRequest: (options, handler) {
  //     final token = ref.read(authTokenProvider);
  //     if (token != null) options.headers['Authorization'] = 'Bearer $token';
  //     handler.next(options);
  //   }),
  // );

  return dio;
});
