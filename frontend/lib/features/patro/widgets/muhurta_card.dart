import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/muhurta.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../data/models/muhurat.dart';
import '../providers/patro_providers.dart';

/// The day's auspicious and inauspicious windows.
///
/// The top half is computed: Rahu Kaal, Gulika Kaal, Yamaganda and Abhijit are
/// fixed fractions of the daylight, so they follow the sunrise and need no
/// data. The bottom half is not: a saait for a marriage comes from a published
/// almanac, so it is shown only when someone has entered one.
class MuhurtaCard extends ConsumerWidget {
  const MuhurtaCard({super.key, required this.date, required this.nepali});

  final DateTime date;
  final bool nepali;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DayMuhurtas m = muhurtasFor(date);
    final List<Muhurat> saait = <Muhurat>[
      for (final Muhurat s
          in ref.watch(muhuratsProvider).asData?.value ?? const <Muhurat>[])
        if (isSameDay(s.date, date)) s,
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
                  Icons.schedule_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'शुभ-अशुभ समय' : 'Auspicious times',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final Muhurta w in m.all) _Window(window: w, nepali: nepali),
            if (!m.hasAbhijit) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                nepali
                    ? 'बुधबार अभिजित मुहूर्त मानिँदैन।'
                    : 'Abhijit is not observed on a Wednesday.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (saait.isNotEmpty) ...<Widget>[
              const Divider(height: 22),
              Text(
                nepali ? 'साइत' : 'Saait',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final Muhurat s in saait) _Saait(saait: s, nepali: nepali),
            ],
          ],
        ),
      ),
    );
  }
}

/// One computed window. Green for the one to seek, red for the three to avoid.
class _Window extends StatelessWidget {
  const _Window({required this.window, required this.nepali});

  final Muhurta window;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tint = window.auspicious ? scheme.tertiary : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 26,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              window.name(nepali: nepali),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${formatClock(window.start, nepali: nepali)} – '
            '${formatClock(window.end, nepali: nepali)}',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One published saait.
class _Saait extends StatelessWidget {
  const _Saait({required this.saait, required this.nepali});

  final Muhurat saait;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String note = saait.note(nepali: nepali);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(saait.kind.icon, size: 15, color: saait.kind.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nepali ? saait.kind.labelNe : saait.kind.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                // Committees differ, so a saait without a source is nobody's
                // authority but the person who typed it. Say which it is.
                if (saait.source.isNotEmpty)
                  Text(
                    saait.source,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            saait.window(nepali: nepali),
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
