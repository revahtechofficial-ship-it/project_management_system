import 'package:dio/dio.dart';

import '../enums/member_role.dart';
import '../models/team_member.dart';

/// Talks to the backend's /api/v1/team endpoints (AGENTS.md §1
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

  /// Changes a member's [role] (admin-only on the server).
  Future<void> setRole(int id, MemberRole role) =>
      _dio.patch<Map<String, dynamic>>(
        '/api/v1/team/$id/role',
        data: <String, dynamic>{'role': role.toJson()},
      );
}
