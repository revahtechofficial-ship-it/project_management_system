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
