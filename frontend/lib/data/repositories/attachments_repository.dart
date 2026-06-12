import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/attachment.dart';

/// Talks to a task's attachment endpoints (AGENTS.md §1 `data/repositories`).
class AttachmentsRepository {
  const AttachmentsRepository(this._dio);

  final Dio _dio;

  /// Attachments on a task, newest first.
  Future<List<Attachment>> list(int taskId) async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/tasks/$taskId/attachments');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Uploads [bytes] as a multipart file attachment.
  Future<void> upload(int taskId, Uint8List bytes, String filename) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/tasks/$taskId/attachments',
      data: form,
    );
  }

  /// Deletes an attachment (uploader or admin on the server).
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/attachments/$id');
}
