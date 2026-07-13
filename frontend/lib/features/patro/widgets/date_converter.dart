import 'package:flutter/material.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/nepali_calendar.dart';
import 'pill_toggle.dart';

/// Converts a date between Bikram Sambat and Gregorian, either way.
///
/// The month dropdown is rebuilt from the year, because a BS month has 29 to
/// 32 days depending on the year — there is no formula, only a table — and a
/// day picker that offered 32 every time would let you ask for a date that
/// does not exist.
class DateConverter extends StatefulWidget {
  const DateConverter({
    super.key,
    required this.nepali,
    required this.onOpenDate,
  });

  final bool nepali;

  /// Jumps the calendar to the converted day.
  final ValueChanged<DateTime> onOpenDate;

  @override
  State<DateConverter> createState() => _DateConverterState();
}

class _DateConverterState extends State<DateConverter> {
  /// True while converting BS to AD.
  bool _bsToAd = true;

  late BsDate _bs = bsToday();
  late DateTime _ad = dateOnly(DateTime.now());

  /// Clamps the day to the length of the month it now sits in — switching from
  /// a 32-day Ashar to a 29-day Falgun must not leave day 32 selected.
  void _setBs(int year, int month, int day) {
    final int length = bsMonthLength(year, month);
    setState(() => _bs = BsDate(year, month, day.clamp(1, length)));
  }

  Future<void> _pickAd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ad,
      firstDate: DateTime(1944),
      lastDate: DateTime(2043, 12, 31),
    );
    if (picked != null) {
      setState(() => _ad = dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool nepali = widget.nepali;

    // Whichever way round, we end up with one Gregorian day and one BS day.
    final DateTime ad = _bsToAd ? bsToAd(_bs.year, _bs.month, _bs.day) : _ad;
    final BsDate bs = _bsToAd ? _bs : adToBs(_ad);
    final int column = sundayFirstIndex(ad);

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
                  Icons.swap_horiz,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'मिति रूपान्तरण' : 'Date converter',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PillToggle(
              labels: const <String>['BS → AD', 'AD → BS'],
              selected: _bsToAd ? 0 : 1,
              onChanged: (int i) => setState(() => _bsToAd = i == 0),
            ),
            const SizedBox(height: 14),
            if (_bsToAd)
              _BsInput(bs: _bs, nepali: nepali, onChanged: _setBs)
            else
              InkWell(
                onTap: _pickAd,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: nepali ? 'अंग्रेजी मिति' : 'Gregorian date',
                    isDense: true,
                    prefixIcon: const Icon(Icons.event_outlined, size: 18),
                  ),
                  child: Text(formatLongDate(_ad)),
                ),
              ),
            const Divider(height: 24),
            _Result(
              label: nepali ? 'नेपाली (वि.सं.)' : 'Nepali (BS)',
              lines: <String>[
                bsDateText(bs, nepali: nepali),
                '${nepali ? kWeekdaysNeLong[column] : kWeekdaysEnLong[column]}'
                    ' · '
                    '${nepali ? kBsMonthsNe[bs.month] : kBsMonthsEn[bs.month]}'
                    ' ${localDigits(bs.year, nepali: nepali)}',
              ],
              emphasis: true,
            ),
            const SizedBox(height: 10),
            _Result(
              label: nepali ? 'अंग्रेजी (ई.सं.)' : 'English (AD)',
              lines: <String>[
                formatLongDate(ad),
                '${kWeekdaysEnLong[column]} · ${monthLong(ad.month)} ${ad.year}',
              ],
              emphasis: false,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.onOpenDate(ad),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  nepali ? 'पात्रोमा हेर्नुहोस्' : 'Show in calendar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Year, month and day pickers for a Bikram Sambat date.
class _BsInput extends StatelessWidget {
  const _BsInput({
    required this.bs,
    required this.nepali,
    required this.onChanged,
  });

  final BsDate bs;
  final bool nepali;
  final void Function(int year, int month, int day) onChanged;

  @override
  Widget build(BuildContext context) {
    // The month's real length, so the day picker cannot offer a day that does
    // not exist.
    final int length = bsMonthLength(bs.year, bs.month);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: bs.year,
            isExpanded: true,
            menuMaxHeight: 300,
            decoration: InputDecoration(
              labelText: nepali ? 'वर्ष' : 'Year',
              isDense: true,
            ),
            items: <DropdownMenuItem<int>>[
              for (int y = kBsPickerMinYear; y <= kBsPickerMaxYear; y++)
                DropdownMenuItem<int>(
                  value: y,
                  child: Text(localDigits(y, nepali: nepali)),
                ),
            ],
            onChanged: (int? v) {
              if (v != null) {
                onChanged(v, bs.month, bs.day);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<int>(
            initialValue: bs.month,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: nepali ? 'महिना' : 'Month',
              isDense: true,
            ),
            items: <DropdownMenuItem<int>>[
              for (int m = 1; m <= 12; m++)
                DropdownMenuItem<int>(
                  value: m,
                  child: Text(nepali ? kBsMonthsNe[m] : kBsMonthsEn[m]),
                ),
            ],
            onChanged: (int? v) {
              if (v != null) {
                onChanged(bs.year, v, bs.day);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: bs.day.clamp(1, length),
            isExpanded: true,
            menuMaxHeight: 300,
            decoration: InputDecoration(
              labelText: nepali ? 'गते' : 'Day',
              isDense: true,
            ),
            items: <DropdownMenuItem<int>>[
              for (int d = 1; d <= length; d++)
                DropdownMenuItem<int>(
                  value: d,
                  child: Text(localDigits(d, nepali: nepali)),
                ),
            ],
            onChanged: (int? v) {
              if (v != null) {
                onChanged(bs.year, bs.month, v);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.label,
    required this.lines,
    required this.emphasis,
  });

  final String label;
  final List<String> lines;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasis
            ? scheme.primary.withValues(alpha: 0.07)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            lines.first,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: emphasis ? scheme.primary : scheme.onSurface,
            ),
          ),
          Text(
            lines.last,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
