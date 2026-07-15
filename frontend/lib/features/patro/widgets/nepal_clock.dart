import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/nepali_calendar.dart';

/// The wall-clock time in Kathmandu, ticking once a second, as a slim bar
/// across the top of the calendar.
///
/// Reads Nepal Standard Time (UTC+05:45) rather than the device clock, so it is
/// right for a teammate travelling abroad — and it names the Nepal date on the
/// right, since abroad that can differ from the day the grid highlights.
///
/// Only the time itself repaints each second (see [_TickingTime]); the bar
/// around it, and the whole page beneath it, are built once and left alone. A
/// clock that redrew the calendar sixty times a minute would be the lag.
class NepalClock extends StatelessWidget {
  const NepalClock({super.key, required this.nepali});

  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = dateOnly(nepalNow());

    return Card(
      elevation: 0,
      color: scheme.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 18,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              nepali ? 'नेपालको समय' : 'Time in Nepal',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            _TickingTime(nepali: nepali),
            const SizedBox(width: 12),
            Text('·', style: TextStyle(color: scheme.outline)),
            const SizedBox(width: 12),
            // The Nepal date sits right beside the time — one continuous run of
            // information from the left, so the bar reads filled rather than as
            // two islands with a void between. It yields first when the bar is
            // tight, since the time and the NPT badge matter more.
            Flexible(
              child: Text(
                fullDualDate(today, nepali: nepali),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'NPT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Just the clock digits, alone in their own stateful widget so the once-a-
/// second [setState] rebuilds these few characters and nothing else.
class _TickingTime extends StatefulWidget {
  const _TickingTime({required this.nepali});

  final bool nepali;

  @override
  State<_TickingTime> createState() => _TickingTimeState();
}

class _TickingTimeState extends State<_TickingTime> {
  Timer? _timer;
  DateTime _now = nepalNow();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = nepalNow());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatClock(_now, nepali: widget.nepali),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}
