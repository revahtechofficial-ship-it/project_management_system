import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../providers/patro_providers.dart';
import 'share_card.dart';

/// Opens the share sheet for [date].
Future<void> showShareDialog(
  BuildContext context, {
  required DateTime date,
  required bool nepali,
  required List<CalendarEvent> events,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) =>
        _ShareDialog(date: date, nepali: nepali, events: events),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({
    required this.date,
    required this.nepali,
    required this.events,
  });

  final DateTime date;
  final bool nepali;
  final List<CalendarEvent> events;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final GlobalKey _cardKey = GlobalKey();
  ShareStyle _style = ShareStyle.date;
  bool _busy = false;

  /// True when the day has no festival, so the festival and greeting styles
  /// have nothing to say. Offering them anyway would produce a card with a
  /// blank where the name should be.
  bool get _hasFestival => cellHoliday(widget.events) != null;

  Future<void> _copyText() async {
    final String text = shareText(
      widget.date,
      nepali: widget.nepali,
      events: widget.events,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      context.showSuccess('Copied');
    }
  }

  /// Renders the card to a PNG and hands it to the browser.
  ///
  /// Captured at 3x, so the image is 1800px square and still looks sharp when
  /// somebody opens it full-screen on a phone.
  Future<void> _saveImage() async {
    setState(() => _busy = true);
    try {
      final RenderRepaintBoundary? boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('the card has not been laid out yet');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (png == null) {
        throw StateError('could not encode the image');
      }
      downloadBytes(
        'patro-${dayKey(widget.date)}.png',
        png.buffer.asUint8List(),
        'image/png',
      );
      if (mounted) {
        context.showSuccess('Image saved');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not make the image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool nepali = widget.nepali;

    final List<ShareStyle> styles = <ShareStyle>[
      ShareStyle.date,
      if (_hasFestival) ShareStyle.festival,
      if (_hasFestival) ShareStyle.greeting,
    ];

    return AlertDialog(
      title: Text(nepali ? 'साझा गर्नुहोस्' : 'Share this day'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (styles.length > 1) ...<Widget>[
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final ShareStyle s in styles)
                      ChoiceChip(
                        selected: _style == s,
                        onSelected: (_) => setState(() => _style = s),
                        label: Text(nepali ? s.labelNe : s.label),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...<Widget>[
                Text(
                  nepali
                      ? 'यो दिन कुनै पर्व छैन, त्यसैले मिति कार्ड मात्र।'
                      : 'No festival falls on this day, so only the date card '
                            'is offered.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Scaled down to fit the dialog; the capture is at full size, so
              // what is saved is 1800px square regardless of what is shown.
              Center(
                child: SizedBox(
                  width: 340,
                  height: 340,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ShareCard(
                        date: widget.date,
                        nepali: nepali,
                        style: _style,
                        events: widget.events,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shareText(widget.date, nepali: nepali, events: widget.events),
                  style: const TextStyle(fontSize: 11.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(nepali ? 'बन्द' : 'Close'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _copyText,
          icon: const Icon(Icons.copy_outlined, size: 17),
          label: Text(nepali ? 'पाठ प्रतिलिपि' : 'Copy text'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _saveImage,
          icon: const Icon(Icons.image_outlined, size: 17),
          label: Text(nepali ? 'तस्बिर' : 'Save image'),
        ),
      ],
    );
  }
}
