import 'package:flutter/material.dart';

/// A file attached to a task, from `GET /api/v1/tasks/{id}/attachments`.
/// Manual JSON serialization per AGENTS.md §9.
class Attachment {
  final int id;
  final int taskId;
  final int? uploaderId;
  final String? uploaderName;
  final String filename;
  final String contentType;
  final int size;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.taskId,
    required this.createdAt,
    this.uploaderId,
    this.uploaderName,
    this.filename = '',
    this.contentType = '',
    this.size = 0,
  });

  /// A human-readable size, e.g. `1.2 MB`.
  String get sizeLabel {
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// An icon hint based on the file type.
  IconData get icon {
    final String t = contentType.toLowerCase();
    final String name = filename.toLowerCase();
    if (t.startsWith('image/')) {
      return Icons.image_outlined;
    }
    if (t.startsWith('video/')) {
      return Icons.movie_outlined;
    }
    if (t.startsWith('audio/')) {
      return Icons.audiotrack_outlined;
    }
    if (t.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }
    if (name.endsWith('.doc') || name.endsWith('.docx') || t.contains('word')) {
      return Icons.description_outlined;
    }
    if (name.endsWith('.xls') ||
        name.endsWith('.xlsx') ||
        name.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    id: json['id'] as int,
    taskId: json['task_id'] as int,
    uploaderId: json['uploader_id'] as int?,
    uploaderName: json['uploader_name'] as String?,
    filename: json['filename'] as String? ?? '',
    contentType: json['content_type'] as String? ?? '',
    size: json['size'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'task_id': taskId,
    'uploader_id': uploaderId,
    'uploader_name': uploaderName,
    'filename': filename,
    'content_type': contentType,
    'size': size,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'Attachment(id: $id, filename: $filename)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment &&
          other.id == id &&
          other.taskId == taskId &&
          other.uploaderId == uploaderId &&
          other.uploaderName == uploaderName &&
          other.filename == filename &&
          other.contentType == contentType &&
          other.size == size &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    uploaderId,
    uploaderName,
    filename,
    contentType,
    size,
    createdAt,
  );
}
