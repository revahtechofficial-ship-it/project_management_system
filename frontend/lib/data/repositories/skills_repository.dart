import 'package:dio/dio.dart';

import '../models/skill.dart';

/// Talks to the backend's /api/v1/skills endpoints (AGENTS.md §1
/// `data/repositories`).
class SkillsRepository {
  const SkillsRepository(this._dio);

  final Dio _dio;

  List<Skill> _parse(Response<List<dynamic>> res) => <Skill>[
        for (final dynamic e in res.data ?? <dynamic>[])
          Skill.fromJson(e as Map<String, dynamic>),
      ];

  /// Every member's skills (for the matrix).
  Future<List<Skill>> all() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/skills'));

  /// The current user's own skills.
  Future<List<Skill>> mine() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/skills/me'));

  /// Adds or updates one of the current user's skills.
  Future<void> upsert(String skill, int level) => _dio.post<void>(
        '/api/v1/skills',
        data: <String, dynamic>{'skill': skill, 'level': level},
      );

  /// Removes one of the current user's skills.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/skills/$id');
}
