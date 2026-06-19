/// One submitted form response, from `GET /pages/{id}/responses`. The answers
/// are a dynamic field-id → value map (AGENTS.md §9 dynamic payload).
class FormResponseEntry {
  final int id;
  final Map<String, dynamic> answers;
  final String submittedByName;
  final DateTime createdAt;

  const FormResponseEntry({
    required this.id,
    required this.createdAt,
    this.answers = const <String, dynamic>{},
    this.submittedByName = '',
  });

  factory FormResponseEntry.fromJson(Map<String, dynamic> json) =>
      FormResponseEntry(
        id: json['id'] as int,
        answers:
            (json['answers'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        submittedByName: json['submitted_by_name'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'answers': answers,
    'submitted_by_name': submittedByName,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'FormResponseEntry(id: $id, by: $submittedByName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormResponseEntry &&
          other.id == id &&
          other.submittedByName == submittedByName &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, submittedByName, createdAt);
}
