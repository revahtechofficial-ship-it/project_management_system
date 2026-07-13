import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/religious_days.dart';
import '../../../data/models/daily_content.dart';
import '../providers/patro_providers.dart';

/// What the day *is*: its fasts and observances, and the quote.
///
/// Two halves, and they come from opposite places. The religious days are
/// computed — an Ekadashi is the eleventh tithi and nothing else. The
/// observances and the quote are written down by somebody, because a UN
/// resolution and a person's words cannot be derived from the moon.
class DaySummaryCard extends ConsumerWidget {
  const DaySummaryCard({super.key, required this.date, required this.nepali});

  final DateTime date;
  final bool nepali;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<ReligiousDay> religious = religiousDaysFor(date);
    final List<Observance> observances = observancesOn(
      ref.watch(observancesProvider).asData?.value ?? const <Observance>[],
      date,
    );
    final Quote? quote = ref.watch(quoteProvider(date)).asData?.value;

    if (religious.isEmpty && observances.isEmpty && quote == null) {
      return const SizedBox.shrink();
    }

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
                  Icons.auto_stories_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'आजको दिन' : 'About this day',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            if (religious.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final ReligiousDay d in religious)
                _ReligiousRow(day: d, nepali: nepali),
            ],

            if (observances.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                nepali ? 'दिवसहरू' : 'Observed today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final Observance o in observances)
                _ObservanceRow(observance: o, nepali: nepali),
            ],

            if (quote != null) ...<Widget>[
              const Divider(height: 22),
              _QuoteBlock(quote: quote, nepali: nepali),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReligiousRow extends StatelessWidget {
  const _ReligiousRow({required this.day, required this.nepali});

  final ReligiousDay day;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String note = day.note(nepali: nepali);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              nepali ? day.kind.labelNe : day.kind.label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: scheme.tertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        day.name(nepali: nepali),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (day.isFast) ...<Widget>[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.no_food_outlined,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservanceRow extends StatelessWidget {
  const _ObservanceRow({required this.observance, required this.nepali});

  final Observance observance;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            observance.scope == 'national'
                ? Icons.flag_outlined
                : Icons.public_outlined,
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              observance.name(nepali: nepali),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quote, required this.nepali});

  final Quote quote;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '“${quote.text(nepali: nepali)}”',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (quote.author.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '— ${quote.author}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
