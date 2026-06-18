import 'package:dio/dio.dart';

import '../../core/utils/api_exception.dart';
import '../../core/utils/date_format.dart';
import '../enums/recurrence_type.dart';
import '../enums/task_priority.dart';
import '../enums/task_status.dart';
import '../models/task.dart';

/// Talks to the backend's /api/v1/tasks endpoints (AGENTS.md §1
/// `data/repositories`, §9 data abstraction).
class TasksRepository {
  const TasksRepository(this._dio);

  final Dio _dio;

  /// Fetches all tasks, newest first.
  Future<List<Task>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/tasks',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Task.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a task. Pass [parentId] to make it a subtask of another task.
  Future<Task> create({
    required String title,
    String description = '',
    int? projectId,
    int? assigneeId,
    DateTime? startDate,
    DateTime? dueDate,
    String statusKey = 'todo',
    int? parentId,
    RecurrenceType recurrence = RecurrenceType.none,
    TaskPriority priority = TaskPriority.none,
    List<String> tags = const <String>[],
    int estimateMinutes = 0,
    List<int>? assigneeIds,
    int? sprintId,
    int points = 0,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/tasks',
          data: <String, dynamic>{
            'title': title,
            'description': description,
            'project_id': projectId,
            'assignee_id': assigneeId,
            'assignee_ids': ?assigneeIds,
            'start_date': dateParam(startDate),
            'due_date': dateParam(dueDate),
            'status': statusKey,
            'parent_id': parentId,
            'recurrence': recurrence.toJson(),
            'priority': priority.toJson(),
            'tags': tags,
            'estimate_minutes': estimateMinutes,
            'sprint_id': sprintId,
            'points': points,
          },
        );
    return _taskFrom(res);
  }

  /// Updates a task's editable fields (title, description, project, assignee,
  /// start/due dates, status, recurrence).
  Future<Task> update(
    int id, {
    required String title,
    String description = '',
    int? projectId,
    int? assigneeId,
    DateTime? startDate,
    DateTime? dueDate,
    String statusKey = 'todo',
    RecurrenceType recurrence = RecurrenceType.none,
    TaskPriority priority = TaskPriority.none,
    List<String> tags = const <String>[],
    int estimateMinutes = 0,
    List<int>? assigneeIds,
    int? sprintId,
    int points = 0,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .put<Map<String, dynamic>>(
          '/api/v1/tasks/$id',
          data: <String, dynamic>{
            'title': title,
            'description': description,
            'project_id': projectId,
            'assignee_id': assigneeId,
            'assignee_ids': ?assigneeIds,
            'start_date': dateParam(startDate),
            'due_date': dateParam(dueDate),
            'status': statusKey,
            'recurrence': recurrence.toJson(),
            'priority': priority.toJson(),
            'tags': tags,
            'estimate_minutes': estimateMinutes,
            'sprint_id': sprintId,
            'points': points,
          },
        );
    return _taskFrom(res);
  }

  /// Lists the subtasks of [parentId].
  Future<List<Task>> listSubtasks(int parentId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/tasks/$parentId/subtasks',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Task.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Moves a task to a new workflow [status] (Kanban drag). `done` is kept in
  /// sync server-side.
  Future<Task> setStatus(int id, TaskStatus status) async {
    final Response<Map<String, dynamic>> res = await _dio
        .patch<Map<String, dynamic>>(
          '/api/v1/tasks/$id/status',
          data: <String, dynamic>{'status': status.toJson()},
        );
    return _taskFrom(res);
  }

  /// Moves a task to a workflow status by its raw key (supports custom
  /// statuses, unlike the enum-typed [setStatus]).
  Future<Task> setStatusKey(int id, String statusKey) async {
    final Response<Map<String, dynamic>> res = await _dio
        .patch<Map<String, dynamic>>(
          '/api/v1/tasks/$id/status',
          data: <String, dynamic>{'status': statusKey},
        );
    return _taskFrom(res);
  }

  /// Moves a task into a sprint (or back to the backlog when [sprintId] is
  /// null) without a full update — used by sprint planning.
  Future<Task> setSprint(int id, int? sprintId) async {
    final Response<Map<String, dynamic>> res = await _dio
        .patch<Map<String, dynamic>>(
          '/api/v1/tasks/$id/sprint',
          data: <String, dynamic>{'sprint_id': sprintId},
        );
    return _taskFrom(res);
  }

  /// Sets the `done` flag of the task identified by [id].
  Future<Task> setDone(int id, {required bool done}) async {
    final Response<Map<String, dynamic>> res = await _dio
        .patch<Map<String, dynamic>>(
          '/api/v1/tasks/$id',
          data: <String, dynamic>{'done': done},
        );
    return _taskFrom(res);
  }

  /// Deletes the task identified by [id].
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/tasks/$id');

  /// Applies one [action] to every task in [ids] in a single request. [value]
  /// is action-specific: a bool for `done`, a status/priority string, a user id
  /// (or null) for `assignee`, and ignored for `delete`.
  Future<void> bulk({
    required List<int> ids,
    required String action,
    Object? value,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/tasks/bulk',
      data: <String, dynamic>{'ids': ids, 'action': action, 'value': value},
    );
  }

  /// Snapshots every task's current start/due as its baseline (planned plan).
  Future<void> setBaseline() => _dio.post<void>('/api/v1/baseline');
}

/// Parses a [Task] from a response body, throwing [ApiException] when the body
/// is missing — avoids a `!` non-null assertion (AGENTS.md §6).
Task _taskFrom(Response<Map<String, dynamic>> res) {
  final Map<String, dynamic>? data = res.data;
  if (data == null) {
    final Uri uri = res.requestOptions.uri;
    throw ApiException('Empty task response from $uri');
  }
  return Task.fromJson(data);
}
