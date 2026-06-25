import 'package:dio/dio.dart';

import '../models/api_key.dart';
import '../models/integration.dart';
import '../models/webhook.dart';

/// The token returned once when an API key is created (with its plaintext).
class CreatedApiKey {
  const CreatedApiKey({required this.token, required this.name});

  final String token;
  final String name;
}

/// Talks to /api/v1/integrations — the integrations hub: connectable apps,
/// personal API keys and outgoing webhooks (AGENTS.md §1 `data/repositories`).
class IntegrationsRepository {
  const IntegrationsRepository(this._dio);

  final Dio _dio;

  // --- catalogue ---
  Future<List<Integration>> integrations() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/integrations',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Integration.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> connect(
    String provider, {
    required bool connected,
    Map<String, String> config = const <String, String>{},
  }) => _dio.put<void>(
    '/api/v1/integrations/$provider',
    data: <String, dynamic>{'connected': connected, 'config': config},
  );

  Future<void> disconnect(String provider) =>
      _dio.delete<void>('/api/v1/integrations/$provider');

  // --- API keys ---
  Future<List<ApiKey>> apiKeys() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/integrations/api-keys',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ApiKey.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<CreatedApiKey> createKey(String name) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/integrations/api-keys',
          data: <String, dynamic>{'name': name},
        );
    final Map<String, dynamic> data = res.data ?? const <String, dynamic>{};
    return CreatedApiKey(
      token: data['token'] as String? ?? '',
      name: data['name'] as String? ?? name,
    );
  }

  Future<void> deleteKey(int id) =>
      _dio.delete<void>('/api/v1/integrations/api-keys/$id');

  // --- webhooks ---
  Future<List<Webhook>> webhooks() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/integrations/webhooks',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Webhook.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> createWebhook({
    required String url,
    required List<String> events,
    String secret = '',
    String provider = 'custom',
  }) => _dio.post<void>(
    '/api/v1/integrations/webhooks',
    data: <String, dynamic>{
      'url': url,
      'secret': secret,
      'events': events,
      'provider': provider,
    },
  );

  Future<void> updateWebhook(
    int id, {
    required String url,
    required List<String> events,
    required bool active,
  }) => _dio.patch<void>(
    '/api/v1/integrations/webhooks/$id',
    data: <String, dynamic>{'url': url, 'events': events, 'active': active},
  );

  Future<void> deleteWebhook(int id) =>
      _dio.delete<void>('/api/v1/integrations/webhooks/$id');

  Future<void> testWebhook(int id) =>
      _dio.post<void>('/api/v1/integrations/webhooks/$id/test');
}
