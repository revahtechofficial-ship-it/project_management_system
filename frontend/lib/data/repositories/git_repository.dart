import 'package:dio/dio.dart';

import '../models/git_commit.dart';
import '../models/git_repo.dart';

/// Talks to the backend's /api/v1/git endpoints (AGENTS.md §1
/// `data/repositories`).
class GitRepository {
  const GitRepository(this._dio);

  final Dio _dio;

  /// Registered repositories with commit counts.
  Future<List<GitRepo>> repos() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/git/repos',
    );
    return <GitRepo>[
      for (final dynamic e in res.data ?? <dynamic>[])
        GitRepo.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Registers a repository and returns it with its generated webhook token.
  Future<GitRepo> createRepo({
    required String name,
    required String provider,
    String url = '',
    String defaultBranch = 'main',
    int? projectId,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/git/repos',
          data: <String, dynamic>{
            'name': name,
            'provider': provider,
            'url': url,
            'default_branch': defaultBranch,
            'project_id': projectId,
          },
        );
    return GitRepo.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Removes a repository and its ingested commits.
  Future<void> deleteRepo(int id) => _dio.delete<void>('/api/v1/git/repos/$id');

  /// The most recent commits across all repositories.
  Future<List<GitCommit>> commits() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/git/commits',
    );
    return <GitCommit>[
      for (final dynamic e in res.data ?? <dynamic>[])
        GitCommit.fromJson(e as Map<String, dynamic>),
    ];
  }
}
