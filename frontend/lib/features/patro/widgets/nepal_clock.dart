import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/nepali_calendar.dart';

/// The wall-clock time in Kathmandu, ticking once a second.
///
/// Reads Nepal Standard Time (UTC+05:45) rather than the device clock, so it
/// is right for a teammate travelling abroad. When the device is not on Nepal
/// time it also says which day it is there, since that can differ from the
/// day the grid highlights.
class NepalClock extends StatefulWidget {
  const NepalClock({super.key, required this.nepali});

  final bool nepali;

  @override
  State<NepalClock> createState() => _NepalClockState();
}

class _NepalClockState extends State<NepalClock> {
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool nepali = widget.nepali;
    final DateTime nepalDate = DateTime(_now.year, _now.month, _now.day);
    final bool differsFromDevice = !isSameDay(nepalDate, DateTime.now());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 20,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nepali ? 'नेपालको समय' : 'Time in Nepal',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatClock(_now, nepali: nepali),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  if (differsFromDevice)
                    Text(
                      fullDualDate(nepalDate, nepali: nepali),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              'NPT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
