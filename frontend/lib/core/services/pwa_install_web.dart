import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The `beforeinstallprompt` event, which carries a `prompt()` method.
extension type _InstallPromptEvent(JSObject _) implements JSObject {
  external void prompt();
}

JSObject? _deferred;
void Function()? _onChange;

/// Registers the browser listeners that capture the install prompt. Call once
/// at startup so the event isn't missed.
void initPwaInstall() {
  web.window.addEventListener(
    'beforeinstallprompt',
    (web.Event e) {
      // Stop Chrome's default mini-infobar; we surface our own button instead.
      e.preventDefault();
      _deferred = e;
      _onChange?.call();
    }.toJS,
  );
  web.window.addEventListener(
    'appinstalled',
    (web.Event e) {
      _deferred = null;
      _onChange?.call();
    }.toJS,
  );
}

/// Registers a callback fired when install availability changes, so the UI can
/// show/hide the install button reactively.
void setPwaChangeListener(void Function()? cb) => _onChange = cb;

/// Whether an install prompt is currently available.
bool pwaInstallAvailable() => _deferred != null;

/// Shows the browser's install prompt, if one was captured.
Future<void> promptPwaInstall() async {
  final JSObject? d = _deferred;
  if (d == null) {
    return;
  }
  _InstallPromptEvent(d).prompt();
  _deferred = null;
  _onChange?.call();
}
