import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A lightweight Markdown renderer covering the common blocks — headings,
/// bold/italic, inline code, fenced code, bullet/numbered lists, blockquotes,
/// horizontal rules, links and images — without any third-party dependency.
///
/// It is intentionally small: it handles the syntax our Docs need (including
/// embedded images and links) rather than the full CommonMark spec.
class MarkdownView extends StatefulWidget {
  const MarkdownView({super.key, required this.data});

  final String data;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  static final RegExp _inline = RegExp(
    r'(\*\*([^*]+)\*\*)'
    r'|(\*([^*]+)\*)'
    r'|(`([^`]+)`)'
    r'|(!\[[^\]]*\]\(([^)]+)\))'
    r'|(\[([^\]]+)\]\(([^)]+)\))',
  );
  static final RegExp _imageLine = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$');
  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*\d+\.\s+(.*)$');

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> lines = widget.data.replaceAll('\r\n', '\n').split('\n');
    final List<Widget> blocks = <Widget>[];

    int i = 0;
    while (i < lines.length) {
      final String line = lines[i];

      // Fenced code block.
      if (line.trimLeft().startsWith('```')) {
        final List<String> code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        i++; // skip closing fence
        blocks.add(_codeBlock(scheme, code.join('\n')));
        continue;
      }

      // Image on its own line.
      final RegExpMatch? img = _imageLine.firstMatch(line);
      if (img != null) {
        blocks.add(_image(img.group(2)!.trim()));
        i++;
        continue;
      }

      // Heading.
      final RegExpMatch? h = _heading.firstMatch(line);
      if (h != null) {
        blocks.add(_headingWidget(scheme, h.group(1)!.length, h.group(2)!));
        i++;
        continue;
      }

      // Horizontal rule.
      if (RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line)) {
        blocks.add(const Divider(height: 24));
        i++;
        continue;
      }

      // Blockquote.
      if (line.trimLeft().startsWith('> ')) {
        final List<String> quote = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('> ')) {
          quote.add(lines[i].trimLeft().substring(2));
          i++;
        }
        blocks.add(_blockquote(scheme, quote.join('\n')));
        continue;
      }

      // Bullet list.
      if (_bullet.hasMatch(line)) {
        final List<String> items = <String>[];
        while (i < lines.length && _bullet.hasMatch(lines[i])) {
          items.add(_bullet.firstMatch(lines[i])!.group(1)!);
          i++;
        }
        blocks.add(_list(scheme, items, ordered: false));
        continue;
      }

      // Numbered list.
      if (_numbered.hasMatch(line)) {
        final List<String> items = <String>[];
        while (i < lines.length && _numbered.hasMatch(lines[i])) {
          items.add(_numbered.firstMatch(lines[i])!.group(1)!);
          i++;
        }
        blocks.add(_list(scheme, items, ordered: true));
        continue;
      }

      // Blank line.
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // Paragraph: gather consecutive plain lines.
      final List<String> para = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_isBlockStart(lines[i])) {
        para.add(lines[i]);
        i++;
      }
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(children: _spans(para.join(' '), scheme))),
        ),
      );
    }

    if (blocks.isEmpty) {
      return Text(
        'Nothing to preview yet.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  bool _isBlockStart(String line) =>
      _heading.hasMatch(line) ||
      _bullet.hasMatch(line) ||
      _numbered.hasMatch(line) ||
      _imageLine.hasMatch(line) ||
      line.trimLeft().startsWith('```') ||
      line.trimLeft().startsWith('> ');

  Widget _headingWidget(ColorScheme scheme, int level, String text) {
    final double size = <double>[
      26,
      22,
      19,
      17,
      15,
      14,
    ][(level - 1).clamp(0, 5)];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text.rich(
        TextSpan(children: _spans(text, scheme)),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _list(
    ColorScheme scheme,
    List<String> items, {
    required bool ordered,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int n = 0; n < items.length; n++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: Text(
                      ordered ? '${n + 1}.' : '•',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: _spans(items[n], scheme)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _blockquote(ColorScheme scheme, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Text.rich(
        TextSpan(children: _spans(text, scheme)),
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _codeBlock(ColorScheme scheme, String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  Widget _image(String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          errorBuilder: (BuildContext context, Object error, _) => Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.broken_image_outlined, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text('Image: $url')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parses inline markdown into styled spans (bold, italic, code, links).
  List<InlineSpan> _spans(String text, ColorScheme scheme) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int last = 0;
    for (final RegExpMatch m in _inline.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(4),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (m.group(5) != null) {
        spans.add(
          TextSpan(
            text: m.group(6),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        );
      } else if (m.group(7) != null) {
        // Inline image — show its alt/URL as a hint (block images render above).
        spans.add(TextSpan(text: m.group(0)));
      } else if (m.group(9) != null) {
        final String url = m.group(11)!;
        final TapGestureRecognizer recognizer = TapGestureRecognizer()
          ..onTap = () => _open(url);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: m.group(10),
            style: TextStyle(
              color: scheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: recognizer,
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}
