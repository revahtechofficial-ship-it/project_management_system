import '../enums/git_provider.dart';

/// A registered code repository whose push webhook feeds commit activity, from
/// `/api/v1/git/repos`. Manual JSON serialization per AGENTS.md §9.
class GitRepo {
  final int id;
  final String name;
  final GitProvider provider;
  final String url;
  final String defaultBranch;
  final int? projectId;
  final String projectName;
  final String webhookToken;
  final int commitCount;
  final DateTime? lastCommitAt;
  final DateTime createdAt;

  const GitRepo({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.provider = GitProvider.github,
    this.url = '',
    this.defaultBranch = 'main',
    this.projectId,
    this.projectName = '',
    this.webhookToken = '',
    this.commitCount = 0,
    this.lastCommitAt,
  });

  static DateTime? _date(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory GitRepo.fromJson(Map<String, dynamic> json) => GitRepo(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        provider: GitProvider.fromJson(json['provider'] as String? ?? 'github'),
        url: json['url'] as String? ?? '',
        defaultBranch: json['default_branch'] as String? ?? 'main',
        projectId: json['project_id'] as int?,
        projectName: json['project_name'] as String? ?? '',
        webhookToken: json['webhook_token'] as String? ?? '',
        commitCount: json['commit_count'] as int? ?? 0,
        lastCommitAt: _date(json['last_commit_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'provider': provider.toJson(),
        'url': url,
        'default_branch': defaultBranch,
        'project_id': projectId,
        'project_name': projectName,
        'webhook_token': webhookToken,
        'commit_count': commitCount,
        'last_commit_at': lastCommitAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'GitRepo(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitRepo &&
          other.id == id &&
          other.name == name &&
          other.provider == provider &&
          other.url == url &&
          other.defaultBranch == defaultBranch &&
          other.projectId == projectId &&
          other.projectName == projectName &&
          other.webhookToken == webhookToken &&
          other.commitCount == commitCount &&
          other.lastCommitAt == lastCommitAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        provider,
        url,
        defaultBranch,
        projectId,
        projectName,
        webhookToken,
        commitCount,
        lastCommitAt,
        createdAt,
      );
}
