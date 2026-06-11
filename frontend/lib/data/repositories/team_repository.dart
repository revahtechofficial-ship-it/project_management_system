import 'package:dio/dio.dart';

import '../models/team_member.dart';

/// Talks to the backend's /api/v1/team endpoint (AGENTS.md §1
/// `data/repositories`).
class TeamRepository {
  const TeamRepository(this._dio);

  final Dio _dio;

  /// Fetches all workspace members with their task workload.
  Future<List<TeamMember>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/team');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => TeamMember.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
