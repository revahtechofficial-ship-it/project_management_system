import 'package:dio/dio.dart';

/// Whether the AI assistant is configured on the backend.
class AiStatus {
  const AiStatus({required this.configured, this.model = ''});

  final bool configured;
  final String model;

  factory AiStatus.fromJson(Map<String, dynamic> json) => AiStatus(
    configured: json['configured'] as bool? ?? false,
    model: json['model'] as String? ?? '',
  );
}

/// Talks to /api/v1/ai — the Claude-powered assistant (AGENTS.md §1).
class AiRepository {
  const AiRepository(this._dio);

  final Dio _dio;

  Future<AiStatus> status() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/ai/status');
    return AiStatus.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Sends the conversation so far and returns the assistant's reply.
  Future<String> chat(List<Map<String, String>> messages) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/chat',
          data: <String, dynamic>{'messages': messages},
        );
    return (res.data ?? const <String, dynamic>{})['reply'] as String? ?? '';
  }

  /// Rewrites [text] according to [action] (improve / shorten / expand / fix /
  /// professional / summarize).
  Future<String> write(String action, String text) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/write',
          data: <String, dynamic>{'action': action, 'text': text},
        );
    return (res.data ?? const <String, dynamic>{})['result'] as String? ?? '';
  }

  Future<String> summarizeProject(int? projectId) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/summarize',
          data: <String, dynamic>{'project_id': projectId},
        );
    return (res.data ?? const <String, dynamic>{})['summary'] as String? ?? '';
  }

  /// Creates tasks from a natural-language prompt; returns the created count.
  Future<int> createTasks(String prompt, {int? projectId}) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/tasks',
          data: <String, dynamic>{'prompt': prompt, 'project_id': projectId},
        );
    return (res.data ?? const <String, dynamic>{})['count'] as int? ?? 0;
  }

  Future<String> search(String query) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/search',
          data: <String, dynamic>{'query': query},
        );
    return (res.data ?? const <String, dynamic>{})['answer'] as String? ?? '';
  }

  Future<String> meetingNotes(String notes) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/meeting-notes',
          data: <String, dynamic>{'notes': notes},
        );
    return (res.data ?? const <String, dynamic>{})['result'] as String? ?? '';
  }
}
