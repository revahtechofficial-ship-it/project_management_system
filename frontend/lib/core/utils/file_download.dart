// Conditional entry point for triggering a browser file download. The real web
// implementation is used when compiling for the browser; a no-op stub keeps
// tests/analysis on the Dart VM green (mirrors the screen-capture pattern).
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
