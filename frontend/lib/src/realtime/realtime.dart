import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';

/// Opens a WebSocket to the backend's real-time endpoint.
///
/// This is a starting point for live chat / task events. The backend WS handler
/// does not exist yet — once it does, expose this as a StreamProvider and the
/// `ws://.../api/v1/ws` URL below should match the server route.
WebSocketChannel connectRealtime() {
  final wsUrl = '${AppConfig.apiBaseUrl.replaceFirst('http', 'ws')}/api/v1/ws';
  return WebSocketChannel.connect(Uri.parse(wsUrl));
}
