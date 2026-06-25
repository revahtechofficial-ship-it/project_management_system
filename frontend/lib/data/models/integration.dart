/// A connected third-party integration, from `GET /api/v1/integrations`. The
/// [config] holds provider-specific connection details (a webhook URL, an
/// access token, or an account). Manual JSON serialization per AGENTS.md §9.
class Integration {
  final String provider;
  final bool connected;
  final Map<String, String> config;
  final DateTime? updatedAt;

  const Integration({
    required this.provider,
    this.connected = false,
    this.config = const <String, String>{},
    this.updatedAt,
  });

  factory Integration.fromJson(Map<String, dynamic> json) => Integration(
    provider: json['provider'] as String? ?? '',
    connected: json['connected'] as bool? ?? false,
    config: <String, String>{
      for (final MapEntry<String, dynamic> e
          in (json['config'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .entries)
        e.key: '${e.value ?? ''}',
    },
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.tryParse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provider': provider,
    'connected': connected,
    'config': config,
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  String toString() => 'Integration($provider, connected: $connected)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Integration &&
          other.provider == provider &&
          other.connected == connected &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(provider, connected, updatedAt);
}
