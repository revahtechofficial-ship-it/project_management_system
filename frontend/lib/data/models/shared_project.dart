/// A read-only project view served from a public share token
/// (`GET /api/v1/public/projects/{token}`). Manual JSON per AGENTS.md §9.
class SharedProject {
  final int id;
  final String name;
  final String description;
  final String status;
  final DateTime? dueDate;
  final List<SharedTask> tasks;

  const SharedProject({
    required this.id,
    this.name = '',
    this.description = '',
    this.status = 'active',
    this.dueDate,
    this.tasks = const <SharedTask>[],
  });

  int get doneCount => tasks.where((SharedTask t) => t.done).length;

  factory SharedProject.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> p =
        json['project'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return SharedProject(
      id: p['id'] as int? ?? 0,
      name: p['name'] as String? ?? '',
      description: p['description'] as String? ?? '',
      status: p['status'] as String? ?? 'active',
      dueDate: p['due_date'] == null
          ? null
          : DateTime.parse(p['due_date'] as String),
      tasks: <SharedTask>[
        for (final dynamic e in json['tasks'] as List<dynamic>? ?? <dynamic>[])
          SharedTask.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'project': <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
    },
    'tasks': tasks.map((SharedTask t) => t.toJson()).toList(),
  };

  @override
  String toString() => 'SharedProject(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedProject &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.status == status &&
          other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(id, name, description, status, dueDate);
}

/// A minimal, read-only task in a shared project view.
class SharedTask {
  final int id;
  final String title;
  final bool done;
  final String status;
  final DateTime? dueDate;

  const SharedTask({
    required this.id,
    this.title = '',
    this.done = false,
    this.status = 'todo',
    this.dueDate,
  });

  factory SharedTask.fromJson(Map<String, dynamic> json) => SharedTask(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    status: json['status'] as String? ?? 'todo',
    dueDate: json['due_date'] == null
        ? null
        : DateTime.parse(json['due_date'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'done': done,
    'status': status,
    'due_date': dueDate?.toIso8601String(),
  };

  @override
  String toString() => 'SharedTask(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedTask &&
          other.id == id &&
          other.title == title &&
          other.done == done &&
          other.status == status &&
          other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(id, title, done, status, dueDate);
}
