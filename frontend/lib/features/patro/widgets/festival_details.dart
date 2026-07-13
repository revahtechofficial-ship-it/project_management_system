import 'package:flutter/material.dart';

import '../../../data/models/holiday.dart';

/// Everything written about one festival: what it is, where it comes from,
/// why it matters, and how it is kept.
///
/// Sections with no text are omitted rather than shown empty — most days in
/// the table carry only a name.
class FestivalDetails extends StatelessWidget {
  const FestivalDetails({
    super.key,
    required this.holiday,
    required this.nepali,
  });

  final Holiday holiday;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<(String, IconData, Bilingual)> sections =
        <(String, IconData, Bilingual)>[
          (
            nepali ? 'बारेमा' : 'About',
            Icons.info_outline,
            holiday.description,
          ),
          (
            nepali ? 'इतिहास' : 'History',
            Icons.history_edu_outlined,
            holiday.history,
          ),
          (
            nepali ? 'महत्त्व' : 'Importance',
            Icons.star_outline,
            holiday.importance,
          ),
          (
            nepali ? 'कसरी मनाइन्छ' : 'How it is celebrated',
            Icons.celebration_outlined,
            holiday.celebration,
          ),
        ];

    final List<(String, IconData, Bilingual)> present =
        <(String, IconData, Bilingual)>[
          for (final (String, IconData, Bilingual) s in sections)
            if (s.$3.isNotEmpty) s,
        ];

    final List<String> aliases = holiday.aliasList;
    if (present.isEmpty && aliases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The name people actually use often is not the day's formal name:
          // Vijaya Dashami is "Dashain", Raksha Bandhan is "Janai Purnima".
          if (aliases.isNotEmpty) ...<Widget>[
            Text(
              nepali ? 'अन्य नाम' : 'Also known as',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String alias in aliases)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: holiday.category.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alias,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: holiday.category.color,
                      ),
                    ),
                  ),
              ],
            ),
            if (present.isNotEmpty) const SizedBox(height: 12),
          ],
          for (int i = 0; i < present.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _Section(
              title: present[i].$1,
              icon: present[i].$2,
              body: present[i].$3.text(nepali: nepali),
              // Say so when the reader is getting the other language, rather
              // than passing a translation off as one.
              translated: present[i].$3.isFallback(nepali: nepali),
              nepali: nepali,
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.body,
    required this.translated,
    required this.nepali,
  });

  final String title;
  final IconData icon;
  final String body;
  final bool translated;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (translated) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                nepali ? '(अंग्रेजीमा)' : '(in Nepali)',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 12.5, height: 1.45)),
      ],
    );
  }
}
