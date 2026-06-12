import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A resilient client for the chat WebSocket. It decodes JSON event frames and
/// re-publishes them on a broadcast [events] stream, reconnecting on drop.
class ChatSocket {
  ChatSocket(this._url);

  final String _url;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _closed = false;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Decoded `{type, ...}` event frames pushed by the server.
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Sends a JSON frame to the server (e.g. a typing signal). No-op if the
  /// socket is not currently connected.
  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {
      // Dropped frames (e.g. mid-reconnect) are non-fatal.
    }
  }

  void connect() {
    if (_closed) {
      return;
    }
    try {
      final WebSocketChannel channel =
          WebSocketChannel.connect(Uri.parse(_url));
      _channel = channel;
      _sub = channel.stream.listen(
        (dynamic data) {
          try {
            final dynamic decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            }
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onDone: _scheduleReconnect,
        onError: (Object _) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) {
      return;
    }
    _sub?.cancel();
    _channel = null;
    Future<void>.delayed(const Duration(seconds: 3), connect);
  }

  void dispose() {
    _closed = true;
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
