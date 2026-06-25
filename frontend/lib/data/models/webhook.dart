/// An outgoing webhook subscription, from
/// `GET /api/v1/integrations/webhooks`. Manual JSON serialization per
/// AGENTS.md §9.
class Webhook {
  final int id;
  final String url;
  final List<String> events;
  final bool active;
  final String provider;
  final bool hasSecret;

  const Webhook({
    required this.id,
    required this.active,
    required this.hasSecret,
    this.url = '',
    this.events = const <String>[],
    this.provider = 'custom',
  });

  /// Whether this webhook listens to every event (an empty subscription list).
  bool get allEvents => events.isEmpty;

  factory Webhook.fromJson(Map<String, dynamic> json) => Webhook(
    id: json['id'] as int,
    url: json['url'] as String? ?? '',
    events:
        (json['events'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(growable: false),
    active: json['active'] as bool? ?? true,
    provider: json['provider'] as String? ?? 'custom',
    hasSecret: json['has_secret'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'url': url,
    'events': events,
    'active': active,
    'provider': provider,
    'has_secret': hasSecret,
  };

  @override
  String toString() => 'Webhook(id: $id, url: $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Webhook &&
          other.id == id &&
          other.url == url &&
          other.active == active &&
          other.provider == provider &&
          other.hasSecret == hasSecret &&
          _eq(other.events, events);

  @override
  int get hashCode =>
      Object.hash(id, url, active, provider, hasSecret, Object.hashAll(events));

  static bool _eq(List<String> a, List<String> b) {
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
