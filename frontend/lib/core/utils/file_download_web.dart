import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [content] as [filename] by clicking a
/// temporary data-URI anchor. Works for the modest sizes list/report exports
/// produce.
void downloadTextFile(String filename, String content, String mimeType) {
  final String href =
      'data:$mimeType;charset=utf-8,${Uri.encodeComponent(content)}';
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

/// Saves raw bytes — a PNG, say — as a browser download.
///
/// Goes through a Blob rather than a data URI: an image is far too big for the
/// URL-length limits a data URI runs into.
void downloadBytes(String filename, List<int> bytes, String mimeType) {
  final JSArray<web.BlobPart> parts = <web.BlobPart>[
    Uint8List.fromList(bytes).toJS,
  ].toJS;
  final web.Blob blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
