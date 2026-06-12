import 'project_hit.dart';
import 'task.dart';

/// One page of global-search results: matching tasks (paginated) and projects
/// (returned only on the first page). Manual JSON per AGENTS.md §9.
class SearchResults {
  final List<Task> tasks;
  final List<ProjectHit> projects;

  const SearchResults({
    this.tasks = const <Task>[],
    this.projects = const <ProjectHit>[],
  });

  bool get isEmpty => tasks.isEmpty && projects.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        tasks: (json['tasks'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => Task.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        projects: (json['projects'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => ProjectHit.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tasks': tasks.map((Task t) => t.toJson()).toList(),
        'projects': projects.map((ProjectHit p) => p.toJson()).toList(),
      };

  @override
  String toString() =>
      'SearchResults(tasks: ${tasks.length}, projects: ${projects.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResults &&
          _listEq(other.tasks, tasks) &&
          _listEq(other.projects, projects);

  @override
  int get hashCode => Object.hash(Object.hashAll(tasks), Object.hashAll(projects));

  static bool _listEq(List<Object?> a, List<Object?> b) {
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
}
