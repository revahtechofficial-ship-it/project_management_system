// Conditional entry point for the "install this app" (PWA) prompt. The real
// web implementation captures the browser's `beforeinstallprompt` event; a
// no-op stub keeps tests/analysis on the Dart VM green.
export 'pwa_install_stub.dart'
    if (dart.library.html) 'pwa_install_web.dart';
