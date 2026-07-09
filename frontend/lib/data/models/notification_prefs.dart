/// Per-channel delivery preference for one notification category.
class ChannelPref {
  final bool inApp;
  final bool email;

  const ChannelPref({this.inApp = true, this.email = true});

  ChannelPref copyWith({bool? inApp, bool? email}) =>
      ChannelPref(inApp: inApp ?? this.inApp, email: email ?? this.email);

  factory ChannelPref.fromJson(Map<String, dynamic> json) => ChannelPref(
        inApp: json['in_app'] as bool? ?? true,
        email: json['email'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'in_app': inApp, 'email': email};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelPref && other.inApp == inApp && other.email == email;

  @override
  int get hashCode => Object.hash(inApp, email);
}

/// A user's notification preferences, keyed by category (e.g. `assignments`),
/// from `/api/v1/account/notification-prefs`. A missing category defaults to
/// all channels on. Manual JSON serialization per AGENTS.md §9.
class NotificationPrefs {
  final Map<String, ChannelPref> byCategory;

  const NotificationPrefs({this.byCategory = const <String, ChannelPref>{}});

  /// The preference for [category], defaulting to all-on when unset.
  ChannelPref of(String category) =>
      byCategory[category] ?? const ChannelPref();

  /// Returns a copy with [category] set to [pref].
  NotificationPrefs set(String category, ChannelPref pref) =>
      NotificationPrefs(byCategory: <String, ChannelPref>{
        ...byCategory,
        category: pref,
      });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(byCategory: <String, ChannelPref>{
        for (final MapEntry<String, dynamic> e in json.entries)
          if (e.value is Map<String, dynamic>)
            e.key: ChannelPref.fromJson(e.value as Map<String, dynamic>),
      });

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final MapEntry<String, ChannelPref> e in byCategory.entries)
          e.key: e.value.toJson(),
      };

  @override
  String toString() => 'NotificationPrefs(${byCategory.length} set)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPrefs && _mapEq(other.byCategory, byCategory);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        for (final MapEntry<String, ChannelPref> e in byCategory.entries)
          Object.hash(e.key, e.value),
      ]);

  static bool _mapEq(Map<String, ChannelPref> a, Map<String, ChannelPref> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final MapEntry<String, ChannelPref> e in a.entries) {
      if (b[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }
}
