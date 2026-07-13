/// No-op download used off the web (Dart VM / tests). File downloads only make
/// sense in a browser, so there is nothing to do here.
void downloadTextFile(String filename, String content, String mimeType) {}

/// No-op on the Dart VM; the browser implementation saves the bytes.
void downloadBytes(String filename, List<int> bytes, String mimeType) {}
