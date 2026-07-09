import 'package:dio/dio.dart';

import '../models/vikunja_project.dart';

/// Reads Vikunja data through the BFF (AGENTS.md §1 `data/repositories`).
/// The BFF maps the caller's Keycloak identity to their Vikunja token.
class VikunjaRepository {
  const VikunjaRepository(this._dio);

  final Dio _dio;

  Future<List<VikunjaProject>> listProjects() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/vikunja/projects',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => VikunjaProject.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
