import '../enums/release_status.dart';

/// A planned release / version, from `GET /api/v1/releases`. Tasks reference it
/// via `release_id`. Manual JSON serialization per AGENTS.md §9.
class Release {
  final int id;
  final String name;
  final String version;
  final ReleaseStatus status;
  final DateTime? targetDate;
  final String notes;

  const Release({
    required this.id,
    this.name = '',
    this.version = '',
    this.status = ReleaseStatus.planned,
    this.targetDate,
    this.notes = '',
  });

  /// The display label, combining name and version when both are present.
  String get displayName => version.isEmpty ? name : '$name · $version';

  factory Release.fromJson(Map<String, dynamic> json) => Release(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    version: json['version'] as String? ?? '',
    status: ReleaseStatus.fromJson(json['status'] as String? ?? 'planned'),
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date'] as String),
    notes: json['notes'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'version': version,
    'status': status.toJson(),
    'target_date': targetDate == null
        ? null
        : '${targetDate!.year.toString().padLeft(4, '0')}-'
              '${targetDate!.month.toString().padLeft(2, '0')}-'
              '${targetDate!.day.toString().padLeft(2, '0')}',
    'notes': notes,
  };

  @override
  String toString() => 'Release(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Release &&
          other.id == id &&
          other.name == name &&
          other.version == version &&
          other.status == status &&
          other.targetDate == targetDate &&
          other.notes == notes;

  @override
  int get hashCode => Object.hash(id, name, version, status, targetDate, notes);
}
