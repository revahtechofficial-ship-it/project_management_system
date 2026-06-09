import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_config.dart';
import '../core/services/logger.dart';
import 'auth_provider.dart';

/// Shared Dio HTTP client for the Go BFF (AGENTS.md §1 `providers`). Attaches
/// the current Keycloak access token to every request.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        // Read lazily per request so the latest token is always used.
        final String? token =
            ref.read(authControllerProvider).asData?.value.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, ErrorInterceptorHandler handler) {
        logger.e(
          'HTTP ${e.requestOptions.method} '
          '${e.requestOptions.path} failed',
          error: e,
        );
        handler.next(e);
      },
    ),
  );

  return dio;
});
