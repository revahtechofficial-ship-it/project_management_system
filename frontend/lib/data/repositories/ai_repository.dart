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

/// Result of the meeting-notes pipeline: a Markdown summary plus the saved
/// page id and the number of tasks created.
class AiMeetingResult {
  const AiMeetingResult({
    required this.summary,
    required this.pageId,
    required this.taskCount,
  });

  final String summary;
  final int pageId;
  final int taskCount;

  factory AiMeetingResult.fromJson(Map<String, dynamic> json) =>
      AiMeetingResult(
        summary: json['summary'] as String? ?? '',
        pageId: json['page_id'] as int? ?? 0,
        taskCount: json['count'] as int? ?? 0,
      );
}

/// An AI-written "what happened this week" recap plus the activity it drew on.
class AiRecapResult {
  const AiRecapResult({
    this.recap = '',
    this.activityCount = 0,
    this.contributors = 0,
    this.days = 7,
  });

  final String recap;
  final int activityCount;
  final int contributors;
  final int days;

  factory AiRecapResult.fromJson(Map<String, dynamic> json) => AiRecapResult(
    recap: json['recap'] as String? ?? '',
    activityCount: json['activity_count'] as int? ?? 0,
    contributors: json['contributors'] as int? ?? 0,
    days: json['days'] as int? ?? 7,
  );
}

/// Talks to /api/v1/ai — the Claude-powered assistant (AGENTS.md §1).
class AiRepository {
  const AiRepository(this._dio);

  final Dio _dio;

  /// Generates a weekly recap of workspace activity over the last [days] days.
  Future<AiRecapResult> recap({int days = 7}) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/recap',
          data: <String, dynamic>{'days': days},
        );
    return AiRecapResult.fromJson(res.data ?? const <String, dynamic>{});
  }

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

  /// Turns a transcript/notes into a saved notes page plus real tasks.
  Future<AiMeetingResult> meetingSummary(
    String transcript, {
    String? title,
    int? projectId,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/ai/meeting-summary',
          data: <String, dynamic>{
            'transcript': transcript,
            'title': title,
            'project_id': projectId,
          },
        );
    return AiMeetingResult.fromJson(res.data ?? const <String, dynamic>{});
  }
}
