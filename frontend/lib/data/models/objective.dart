import '../enums/objective_status.dart';
import 'key_result.dart';

/// An objective (a Goal/OKR) with its measurable key results, owner, period and
/// alignment (an optional parent objective). Manual JSON per AGENTS.md §9.
class Objective {
  final int id;
  final String title;
  final String description;
  final int? ownerId;
  final String ownerName;
  final int? parentId;
  final String period;
  final ObjectiveStatus status;
  final double progress;
  final List<KeyResult> keyResults;
  final bool canManage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Objective({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.description = '',
    this.ownerId,
    this.ownerName = '',
    this.parentId,
    this.period = '',
    this.status = ObjectiveStatus.active,
    this.progress = 0,
    this.keyResults = const <KeyResult>[],
    this.canManage = false,
  });

  /// Progress as a 0–100 percentage.
  int get percent => (progress * 100).round();

  factory Objective.fromJson(Map<String, dynamic> json) => Objective(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    ownerId: json['owner_id'] as int?,
    ownerName: json['owner_name'] as String? ?? '',
    parentId: json['parent_id'] as int?,
    period: json['period'] as String? ?? '',
    status: ObjectiveStatus.fromJson(json['status'] as String? ?? ''),
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    keyResults: (json['key_results'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => KeyResult.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    canManage: json['can_manage'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'parent_id': parentId,
    'period': period,
    'status': status.toJson(),
    'progress': progress,
    'key_results': keyResults.map((KeyResult e) => e.toJson()).toList(),
    'can_manage': canManage,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  String toString() => 'Objective(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Objective &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.ownerId == ownerId &&
          other.parentId == parentId &&
          other.period == period &&
          other.status == status &&
          other.progress == progress &&
          other.canManage == canManage;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    ownerId,
    parentId,
    period,
    status,
    progress,
    canManage,
  );
}
