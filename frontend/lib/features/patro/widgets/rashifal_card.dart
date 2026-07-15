import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/religious_days.dart';
import '../../../data/models/daily_content.dart';
import '../providers/patro_providers.dart';
import 'pill_toggle.dart';

/// The rashifal, and the moon's sign.
///
/// The sign is computed — it is the twelfth of the sky the moon stands in, and
/// the calendar knows exactly where the moon is. The *reading* is not, and
/// cannot be: a rashifal is composed by an astrologer, and there is no formula
/// that turns a lunar longitude into a sentence about somebody's week.
///
/// So when nobody has entered readings, this card says that plainly instead of
/// producing a prediction, which would be the one thing on this page that was
/// simply invented.
class RashifalCard extends ConsumerStatefulWidget {
  const RashifalCard({super.key, required this.date, required this.nepali});

  final DateTime date;
  final bool nepali;

  @override
  ConsumerState<RashifalCard> createState() => _RashifalCardState();
}

class _RashifalCardState extends ConsumerState<RashifalCard> {
  /// Which sign the reader is looking at. Starts on the moon's own sign, so
  /// the card is useful before anyone touches it.
  int? _selected;

  static const List<String> _periods = <String>['daily', 'weekly', 'monthly'];
  String _period = 'daily';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool nepali = widget.nepali;

    final Rashi moon = moonRashiOn(widget.date);
    final int selected = _selected ?? moon.index;
    final Rashi shown = rashiOf(selected);

    final List<Rashifal> all =
        ref.watch(rashifalProvider(widget.date)).asData?.value ??
        const <Rashifal>[];
    final List<Rashifal> forSign = <Rashifal>[
      for (final Rashifal r in all)
        if (r.rashi == selected && r.period == _period) r,
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.stars_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'राशिफल' : 'Rashifal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // The one fact on this card that is a fact.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nepali ? 'आजको चन्द्र राशि' : "Today's moon sign",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${moon.name(nepali: nepali)} · ${moon.westernName}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sign picker.
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (int i = 0; i < 12; i++)
                  _SignChip(
                    rashi: rashiOf(i),
                    nepali: nepali,
                    selected: i == selected,
                    isMoonSign: i == moon.index,
                    onTap: () => setState(() => _selected = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // A hand-rolled toggle, not a SegmentedButton: that widget lays its
            // segments in a Row that will not shrink, so on a phone "Monthly"
            // (or Devanagari that mismeasures on the web) spills past the card.
            // PillToggle sizes to its labels and never overflows.
            PillToggle(
              expand: true,
              labels: <String>[
                for (final String p in _periods)
                  switch (p) {
                    'daily' => nepali ? 'दैनिक' : 'Daily',
                    'weekly' => nepali ? 'साप्ताहिक' : 'Weekly',
                    _ => nepali ? 'मासिक' : 'Monthly',
                  },
              ],
              selected: _periods.indexOf(_period),
              onChanged: (int i) => setState(() => _period = _periods[i]),
            ),
            const SizedBox(height: 12),

            if (forSign.isEmpty)
              _NoReading(nepali: nepali, rashi: shown, period: _period)
            else
              for (final Rashifal r in forSign)
                _Reading(reading: r, nepali: nepali),
          ],
        ),
      ),
    );
  }
}

class _SignChip extends StatelessWidget {
  const _SignChip({
    required this.rashi,
    required this.nepali,
    required this.selected,
    required this.isMoonSign,
    required this.onTap,
  });

  final Rashi rashi;
  final bool nepali;
  final bool selected;
  final bool isMoonSign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // A ring on the sign the moon is actually in today.
            border: isMoonSign && !selected
                ? Border.all(color: scheme.primary, width: 1.2)
                : null,
          ),
          child: Text(
            rashi.name(nepali: nepali),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.reading, required this.nepali});

  final Rashifal reading;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          reading.text(nepali: nepali),
          style: const TextStyle(fontSize: 12.5, height: 1.5),
        ),
        // Committees and astrologers differ. A reading with no source is
        // nobody's but whoever typed it, and the reader should know which.
        if (reading.source.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '— ${reading.source}',
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown when there is no reading. Says why rather than filling the space.
class _NoReading extends StatelessWidget {
  const _NoReading({
    required this.nepali,
    required this.rashi,
    required this.period,
  });

  final bool nepali;
  final Rashi rashi;
  final String period;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            nepali
                ? '${rashi.nameNe} को राशिफल लेखिएको छैन।'
                : 'No reading has been written for ${rashi.nameEn}.',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            nepali
                ? 'राशिफल ज्योतिषीले लेख्नुहुन्छ — यो गणनाबाट निस्कँदैन। '
                      'प्रशासकले राशिफल थपेपछि यहाँ देखिनेछ।'
                : 'A rashifal is written by an astrologer; there is no formula '
                      'that produces one. Rather than invent a prediction, '
                      'this stays empty until an admin enters the readings.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
