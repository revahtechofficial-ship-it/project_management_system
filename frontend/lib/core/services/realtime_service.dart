import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_config.dart';

/// Opens a WebSocket to the backend's real-time endpoint (AGENTS.md §1
/// `core/services`).
///
/// Starting point for live chat / task events. The backend WS handler does
/// not exist yet — once it does, expose this via a StreamProvider and ensure
/// the `ws://.../api/v1/ws` path matches the server route.
WebSocketChannel connectRealtime() {
  final String wsUrl =
      '${AppConfig.apiBaseUrl.replaceFirst('http', 'ws')}/api/v1/ws';
  return WebSocketChannel.connect(Uri.parse(wsUrl));
}
