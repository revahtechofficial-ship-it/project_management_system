import 'package:dio/dio.dart';

import '../models/client.dart';
import '../models/portal_data.dart';

/// A project with a flag for whether it belongs to a given client.
typedef ClientProjectFlag = ({int id, String name, bool assigned});

/// Talks to the backend's /api/v1/clients endpoints and the public portal
/// (AGENTS.md §1 `data/repositories`).
class ClientsRepository {
  const ClientsRepository(this._dio);

  final Dio _dio;

  /// All clients with their project counts.
  Future<List<Client>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/clients');
    return <Client>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Client.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Creates a client and returns it with its generated portal token.
  Future<Client> create({
    String name = '',
    String company = '',
    String email = '',
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/clients',
      data: <String, dynamic>{
        'name': name,
        'company': company,
        'email': email,
      },
    );
    return Client.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Saves edits to a client's details.
  Future<void> update(
    int id, {
    String name = '',
    String company = '',
    String email = '',
  }) =>
      _dio.patch<void>(
        '/api/v1/clients/$id',
        data: <String, dynamic>{
          'name': name,
          'company': company,
          'email': email,
        },
      );

  /// Removes a client (unassigning their projects).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/clients/$id');

  /// All projects with a flag for whether they belong to [clientId].
  Future<List<ClientProjectFlag>> projects(int clientId) async {
    final Response<List<dynamic>> res = await _dio
        .get<List<dynamic>>('/api/v1/clients/$clientId/projects');
    return <ClientProjectFlag>[
      for (final dynamic e in res.data ?? <dynamic>[])
        (
          id: (e as Map<String, dynamic>)['id'] as int,
          name: e['name'] as String? ?? '',
          assigned: e['assigned'] as bool? ?? false,
        ),
    ];
  }

  /// Sets which projects belong to a client.
  Future<void> setProjects(int clientId, List<int> projectIds) =>
      _dio.put<void>(
        '/api/v1/clients/$clientId/projects',
        data: <String, dynamic>{'project_ids': projectIds},
      );

  /// Fetches a client's portal by [token] (no auth required).
  Future<PortalData> portal(String token) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>('/api/v1/portal/$token');
    return PortalData.fromJson(res.data ?? <String, dynamic>{});
  }
}
