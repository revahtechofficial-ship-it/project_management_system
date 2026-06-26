/// A user-set reminder, from `GET /api/v1/reminders`. Fires an inbox
/// notification at [remindAt]. Manual JSON serialization per AGENTS.md §9.
class Reminder {
  final int id;
  final int? taskId;
  final String taskTitle;
  final String note;
  final DateTime remindAt;
  final bool sent;

  const Reminder({
    required this.id,
    required this.remindAt,
    this.taskId,
    this.taskTitle = '',
    this.note = '',
    this.sent = false,
  });

  /// The text to show for this reminder.
  String get label => note.isNotEmpty
      ? note
      : (taskTitle.isNotEmpty ? taskTitle : 'Reminder');

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as int,
    taskId: json['task_id'] as int?,
    taskTitle: json['task_title'] as String? ?? '',
    note: json['note'] as String? ?? '',
    remindAt: DateTime.parse(json['remind_at'] as String),
    sent: json['sent'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'task_id': taskId,
    'task_title': taskTitle,
    'note': note,
    'remind_at': remindAt.toIso8601String(),
    'sent': sent,
  };

  @override
  String toString() => 'Reminder(id: $id, at: $remindAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          other.id == id &&
          other.taskId == taskId &&
          other.note == note &&
          other.remindAt == remindAt &&
          other.sent == sent;

  @override
  int get hashCode => Object.hash(id, taskId, note, remindAt, sent);
}
