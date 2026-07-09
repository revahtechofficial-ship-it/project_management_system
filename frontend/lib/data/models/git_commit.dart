/// One commit ingested from a repository's push webhook, from
/// `/api/v1/git/commits`. Manual JSON serialization per AGENTS.md §9.
class GitCommit {
  final int id;
  final int repoId;
  final String repoName;
  final String sha;
  final String shortSha;
  final String message;
  final String authorName;
  final String authorEmail;
  final String url;
  final String branch;
  final int? taskRef;
  final String taskTitle;
  final DateTime committedAt;

  const GitCommit({
    required this.id,
    required this.repoId,
    required this.committedAt,
    this.repoName = '',
    this.sha = '',
    this.shortSha = '',
    this.message = '',
    this.authorName = '',
    this.authorEmail = '',
    this.url = '',
    this.branch = '',
    this.taskRef,
    this.taskTitle = '',
  });

  /// The first line of the commit message (the summary).
  String get summary {
    final int nl = message.indexOf('\n');
    return nl == -1 ? message : message.substring(0, nl);
  }

  factory GitCommit.fromJson(Map<String, dynamic> json) => GitCommit(
    id: json['id'] as int,
    repoId: json['repo_id'] as int,
    repoName: json['repo_name'] as String? ?? '',
    sha: json['sha'] as String? ?? '',
    shortSha: json['short_sha'] as String? ?? '',
    message: json['message'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    authorEmail: json['author_email'] as String? ?? '',
    url: json['url'] as String? ?? '',
    branch: json['branch'] as String? ?? '',
    taskRef: json['task_ref'] as int?,
    taskTitle: json['task_title'] as String? ?? '',
    committedAt: DateTime.parse(json['committed_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'repo_id': repoId,
    'repo_name': repoName,
    'sha': sha,
    'short_sha': shortSha,
    'message': message,
    'author_name': authorName,
    'author_email': authorEmail,
    'url': url,
    'branch': branch,
    'task_ref': taskRef,
    'task_title': taskTitle,
    'committed_at': committedAt.toIso8601String(),
  };

  @override
  String toString() => 'GitCommit(sha: $shortSha, $summary)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitCommit &&
          other.id == id &&
          other.repoId == repoId &&
          other.repoName == repoName &&
          other.sha == sha &&
          other.message == message &&
          other.authorName == authorName &&
          other.authorEmail == authorEmail &&
          other.url == url &&
          other.branch == branch &&
          other.taskRef == taskRef &&
          other.taskTitle == taskTitle &&
          other.committedAt == committedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    repoId,
    repoName,
    sha,
    message,
    authorName,
    authorEmail,
    url,
    branch,
    taskRef,
    taskTitle,
    committedAt,
  ]);
}
