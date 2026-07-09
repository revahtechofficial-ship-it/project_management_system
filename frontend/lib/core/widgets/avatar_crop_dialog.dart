import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/feedback.dart';

/// Lets the user pan/zoom an image inside a circular frame and returns the
/// framed result as PNG bytes (or null if cancelled). Works on web by capturing
/// a [RepaintBoundary] — no native cropper needed.
Future<Uint8List?> cropAvatar(BuildContext context, Uint8List bytes) {
  return showDialog<Uint8List>(
    context: context,
    builder: (BuildContext context) => _AvatarCropDialog(bytes: bytes),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.bytes});
  final Uint8List bytes;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  static const double _size = 280;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Let the final transform settle before capturing.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showError('Could not crop image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Adjust photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Drag to reposition · scroll or pinch to zoom',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                children: <Widget>[
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: ClipRect(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        clipBehavior: Clip.none,
                        child: Image.memory(
                          widget.bytes,
                          width: _size,
                          height: _size,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Circular guide overlay (does not get captured separately —
                  // it sits above the RepaintBoundary).
                  const IgnorePointer(
                    child: CustomPaint(
                      size: Size(_size, _size),
                      painter: _CircleGuidePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Use photo'),
        ),
      ],
    );
  }
}

class _CircleGuidePainter extends CustomPainter {
  const _CircleGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = size.width / 2;
    final Offset center = rect.center;

    // Darken the corners outside the circle.
    final Path overlay = Path()
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // The crop ring.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
