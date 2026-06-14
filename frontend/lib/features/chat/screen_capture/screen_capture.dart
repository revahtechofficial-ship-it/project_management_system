// Conditional entry point: the real web implementation is used when compiling
// for the browser; a no-op stub is used everywhere else (so tests/analysis on
// the Dart VM stay green).
export 'screen_capture_stub.dart'
    if (dart.library.html) 'screen_capture_web.dart';
