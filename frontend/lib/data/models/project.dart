import '../enums/project_status.dart';

/// A project (sample/BFF-shaped). Manual JSON serialization per AGENTS.md §9.
class Project {
  final int id;
  final String name;
  final String description;
  final ProjectStatus status;
  final int totalTasks;
  final int doneTasks;
  final DateTime? dueDate;
  final List<String> memberNames;
  final int? spaceId;
  final int? folderId;

  /// The caller's effective role on this project: `viewer`, `editor` or
  /// `manager`. Defaults to `manager` so an older response stays permissive.
  final String myRole;

  const Project({
    required this.id,
    required this.status,
    this.name = '',
    this.description = '',
    this.totalTasks = 0,
    this.doneTasks = 0,
    this.dueDate,
    this.memberNames = const <String>[],
    this.spaceId,
    this.folderId,
    this.myRole = 'manager',
  });

  /// Fraction of this project's tasks that are complete, in `0.0`–`1.0`.
  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;

  /// Whether the caller administers this project (settings, membership).
  bool get canManage => myRole == 'manager';

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    status: ProjectStatus.fromJson(json['status'] as String? ?? ''),
    totalTasks: json['total_tasks'] as int? ?? 0,
    doneTasks: json['done_tasks'] as int? ?? 0,
    dueDate: json['due_date'] == null
        ? null
        : DateTime.parse(json['due_date'] as String),
    memberNames:
        (json['member_names'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList() ??
        const <String>[],
    spaceId: json['space_id'] as int?,
    folderId: json['folder_id'] as int?,
    myRole: json['my_role'] as String? ?? 'manager',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'status': status.toJson(),
    'total_tasks': totalTasks,
    'done_tasks': doneTasks,
    'due_date': dueDate?.toIso8601String(),
    'member_names': memberNames,
    'space_id': spaceId,
    'folder_id': folderId,
    'my_role': myRole,
  };

  @override
  String toString() =>
      'Project('
      'id: $id, name: $name, status: $status, '
      'totalTasks: $totalTasks, doneTasks: $doneTasks, '
      'dueDate: $dueDate, memberNames: $memberNames)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.status == status &&
          other.totalTasks == totalTasks &&
          other.doneTasks == doneTasks &&
          other.dueDate == dueDate &&
          other.spaceId == spaceId &&
          other.folderId == folderId &&
          other.myRole == myRole &&
          _sameList(other.memberNames, memberNames);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    status,
    totalTasks,
    doneTasks,
    dueDate,
    spaceId,
    folderId,
    myRole,
    Object.hashAll(memberNames),
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
