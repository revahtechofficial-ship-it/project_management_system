import 'package:flutter/material.dart';

import '../enums/task_status.dart';

/// A customizable task workflow status (a board column), from
/// `GET /api/v1/statuses`. Manual JSON serialization per AGENTS.md §9.
class WorkflowStatus {
  final int id;
  final String key;
  final String label;
  final String colorHex;
  final int position;
  final bool protected;

  const WorkflowStatus({
    required this.id,
    this.key = '',
    this.label = '',
    this.colorHex = '#64748b',
    this.position = 0,
    this.protected = false,
  });

  /// The parsed display color (falls back to slate on a malformed hex).
  Color get color {
    final String h = colorHex.replaceFirst('#', '');
    final int? v = int.tryParse(h, radix: 16);
    if (v == null || h.length != 6) {
      return const Color(0xFF64748B);
    }
    return Color(0xFF000000 | v);
  }

  /// The five built-in statuses, used as a fallback before the live list has
  /// loaded (keeps the board/dropdowns populated). Mirrors the server seed.
  static const List<WorkflowStatus> defaults = <WorkflowStatus>[
    WorkflowStatus(
      id: -1,
      key: 'backlog',
      label: 'Backlog',
      colorHex: '#64748b',
    ),
    WorkflowStatus(
      id: -2,
      key: 'todo',
      label: 'To Do',
      colorHex: '#0ea5e9',
      position: 1,
      protected: true,
    ),
    WorkflowStatus(
      id: -3,
      key: 'in_progress',
      label: 'In Progress',
      colorHex: '#6366f1',
      position: 2,
    ),
    WorkflowStatus(
      id: -4,
      key: 'review',
      label: 'Review',
      colorHex: '#8b5cf6',
      position: 3,
    ),
    WorkflowStatus(
      id: -5,
      key: 'done',
      label: 'Done',
      colorHex: '#22c55e',
      position: 4,
      protected: true,
    ),
  ];

  /// Resolves [key] against the loaded statuses, falling back to the built-in
  /// enum's label for the five defaults, or "Unknown" for anything else. Keeps
  /// the UI sensible before the statuses list has loaded.
  static WorkflowStatus forKey(List<WorkflowStatus> all, String key) {
    for (final WorkflowStatus s in all) {
      if (s.key == key) {
        return s;
      }
    }
    final TaskStatus e = TaskStatus.fromJson(key);
    return WorkflowStatus(
      id: -1,
      key: key,
      label: (e == TaskStatus.other && key != 'todo') ? 'Unknown' : e.label,
      colorHex: '#64748b',
    );
  }

  factory WorkflowStatus.fromJson(Map<String, dynamic> json) => WorkflowStatus(
    id: json['id'] as int,
    key: json['key'] as String? ?? '',
    label: json['label'] as String? ?? '',
    colorHex: json['color'] as String? ?? '#64748b',
    position: json['position'] as int? ?? 0,
    protected: json['protected'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'key': key,
    'label': label,
    'color': colorHex,
    'position': position,
    'protected': protected,
  };

  @override
  String toString() => 'WorkflowStatus(id: $id, key: $key, label: $label)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowStatus &&
          other.id == id &&
          other.key == key &&
          other.label == label &&
          other.colorHex == colorHex &&
          other.position == position &&
          other.protected == protected;

  @override
  int get hashCode =>
      Object.hash(id, key, label, colorHex, position, protected);
}
