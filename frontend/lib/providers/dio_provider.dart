import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_config.dart';
import '../core/services/logger.dart';

/// Shared Dio HTTP client, pointed at the backend base URL (AGENTS.md §1
/// `providers` — global, not feature-scoped).
///
/// Attach the OIDC/JWT bearer token here once SSO lands.
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
