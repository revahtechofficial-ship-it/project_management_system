/// Workspace-level security settings, from `GET /api/v1/admin/settings`.
/// Manual JSON serialization per AGENTS.md §9.
class WorkspaceSettings {
  final String name;
  final String allowedDomains;
  final bool require2fa;
  final int sessionHours;
  final bool ssoConfigured;

  const WorkspaceSettings({
    this.name = 'Revah',
    this.allowedDomains = '',
    this.require2fa = false,
    this.sessionHours = 24,
    this.ssoConfigured = false,
  });

  WorkspaceSettings copyWith({
    String? name,
    String? allowedDomains,
    bool? require2fa,
    int? sessionHours,
  }) => WorkspaceSettings(
    name: name ?? this.name,
    allowedDomains: allowedDomains ?? this.allowedDomains,
    require2fa: require2fa ?? this.require2fa,
    sessionHours: sessionHours ?? this.sessionHours,
    ssoConfigured: ssoConfigured,
  );

  factory WorkspaceSettings.fromJson(Map<String, dynamic> json) =>
      WorkspaceSettings(
        name: json['name'] as String? ?? 'Revah',
        allowedDomains: json['allowed_domains'] as String? ?? '',
        require2fa: json['require_2fa'] as bool? ?? false,
        sessionHours: (json['session_hours'] as num?)?.toInt() ?? 24,
        ssoConfigured: json['sso_configured'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'allowed_domains': allowedDomains,
    'require_2fa': require2fa,
    'session_hours': sessionHours,
    'sso_configured': ssoConfigured,
  };

  @override
  String toString() => 'WorkspaceSettings(name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceSettings &&
          other.name == name &&
          other.allowedDomains == allowedDomains &&
          other.require2fa == require2fa &&
          other.sessionHours == sessionHours &&
          other.ssoConfigured == ssoConfigured;

  @override
  int get hashCode =>
      Object.hash(name, allowedDomains, require2fa, sessionHours, ssoConfigured);
}
