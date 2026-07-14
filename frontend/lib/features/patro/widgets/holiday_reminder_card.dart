import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../providers/patro_providers.dart';

/// Whether — and how far ahead — to be told about a coming public holiday.
///
/// A birthday carries its own reminder, because it is one person's. A holiday
/// is the country's, so there is nowhere on the holiday to hang "warn *me*
/// three days before"; the notice period is a setting on the reader instead.
///
/// Off by default. Nobody gets a notification they did not ask for.
class HolidayReminderCard extends ConsumerWidget {
  const HolidayReminderCard({super.key, required this.nepali});

  final bool nepali;

  static const List<int?> _choices = <int?>[null, 0, 1, 3, 7, 14];

  String _label(int? days, bool nepali) => switch (days) {
    null => nepali ? 'बन्द' : 'Off',
    0 => nepali ? 'सोही दिन' : 'On the day',
    1 => nepali ? '१ दिन अघि' : '1 day before',
    3 => nepali ? '३ दिन अघि' : '3 days before',
    7 => nepali ? '१ हप्ता अघि' : 'A week before',
    _ => nepali ? '२ हप्ता अघि' : 'Two weeks before',
  };

  Future<void> _set(BuildContext context, WidgetRef ref, int? days) async {
    try {
      await ref.read(holidaysRepositoryProvider).setReminderDays(days);
      ref.invalidate(holidayReminderProvider);
      if (context.mounted) {
        context.showSuccess(
          days == null ? 'Holiday reminders off' : 'Holiday reminders on',
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<int?> current = ref.watch(holidayReminderProvider);

    // Until it loads, show nothing rather than flash "Off" and then correct
    // itself — a setting that appears to change on its own is alarming.
    if (!current.hasValue) {
      return const SizedBox.shrink();
    }
    final int? days = current.value;

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
                  days == null
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 16,
                  color: days == null
                      ? scheme.onSurfaceVariant
                      : scheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nepali ? 'बिदाको सम्झना' : 'Holiday reminders',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              nepali
                  ? 'आउँदो सार्वजनिक बिदाको सूचना।'
                  : 'A notification before the next public holiday. Only the '
                        'days the office actually closes.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final int? choice in _choices)
                  ChoiceChip(
                    selected: days == choice,
                    onSelected: (_) => _set(context, ref, choice),
                    label: Text(_label(choice, nepali)),
                    labelStyle: const TextStyle(fontSize: 11.5),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
