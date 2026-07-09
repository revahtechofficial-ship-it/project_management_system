import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/shared_project.dart';
import '../../../providers/dio_provider.dart';

/// Talks to the project public-share endpoints.
class ProjectShareRepository {
  const ProjectShareRepository(this._dio);

  final Dio _dio;

  /// The project's current public token, or null when not shared.
  Future<String?> getToken(int projectId) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/projects/$projectId/share');
    return res.data?['token'] as String?;
  }

  /// Publishes (or returns the existing) read-only public link.
  Future<String> enable(int projectId) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>('/api/v1/projects/$projectId/share');
    return res.data?['token'] as String? ?? '';
  }

  /// Disables the public link.
  Future<void> revoke(int projectId) =>
      _dio.delete<void>('/api/v1/projects/$projectId/share');

  /// Fetches a read-only shared project by [token] (no auth required).
  Future<SharedProject> publicProject(String token) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/public/projects/$token');
    return SharedProject.fromJson(res.data ?? <String, dynamic>{});
  }
}

final Provider<ProjectShareRepository> projectShareRepositoryProvider =
    Provider<ProjectShareRepository>((ref) {
      return ProjectShareRepository(ref.watch(dioProvider));
    });

/// The current share token for a project (null when not shared).
final projectShareTokenProvider = FutureProvider.family<String?, int>((
  ref,
  int projectId,
) {
  return ref.watch(projectShareRepositoryProvider).getToken(projectId);
});

/// A read-only shared project, keyed by token.
final sharedProjectProvider = FutureProvider.family<SharedProject, String>((
  ref,
  String token,
) {
  return ref.watch(projectShareRepositoryProvider).publicProject(token);
});
