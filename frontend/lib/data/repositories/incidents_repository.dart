import 'package:dio/dio.dart';

import '../models/incident.dart';

/// Talks to the backend's /api/v1/incidents endpoints (AGENTS.md §1
/// `data/repositories`).
class IncidentsRepository {
  const IncidentsRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _body(Incident i) => <String, dynamic>{
    'title': i.title,
    'description': i.description,
    'kind': i.kind.toJson(),
    'severity': i.severity.toJson(),
    'project_id': i.projectId,
    'assignee_id': i.assigneeId,
    'component': i.component,
  };

  /// Every bug and incident, ordered for triage (active + severe first).
  Future<List<Incident>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/incidents',
    );
    return <Incident>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Incident.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Reports a new bug or incident (reporter is the current user, server-side).
  Future<void> create(Incident i) =>
      _dio.post<void>('/api/v1/incidents', data: _body(i));

  /// Saves edits to an existing issue.
  Future<void> update(int id, Incident i) =>
      _dio.patch<void>('/api/v1/incidents/$id', data: _body(i));

  /// Moves an issue through the triage workflow.
  Future<void> setStatus(int id, String status) => _dio.patch<void>(
    '/api/v1/incidents/$id/status',
    data: <String, dynamic>{'status': status},
  );

  /// Removes an issue.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/incidents/$id');
}
