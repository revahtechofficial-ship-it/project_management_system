/// LiveKit join credentials returned by the call-token endpoint. Manual JSON
/// per AGENTS.md §9.
class CallCredentials {
  final String token;
  final String url;
  final String room;
  final String mode;

  const CallCredentials({
    this.token = '',
    this.url = '',
    this.room = '',
    this.mode = 'video',
  });

  bool get isVideo => mode == 'video';

  factory CallCredentials.fromJson(Map<String, dynamic> json) =>
      CallCredentials(
        token: json['token'] as String? ?? '',
        url: json['url'] as String? ?? '',
        room: json['room'] as String? ?? '',
        mode: json['mode'] as String? ?? 'video',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'token': token,
        'url': url,
        'room': room,
        'mode': mode,
      };

  @override
  String toString() => 'CallCredentials(room: $room, mode: $mode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallCredentials &&
          other.token == token &&
          other.url == url &&
          other.room == room &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(token, url, room, mode);
}
