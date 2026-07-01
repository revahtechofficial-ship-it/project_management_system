import 'package:flutter/widgets.dart';

/// The app's 8-pt spacing scale. Prefer these over ad-hoc numbers so gaps stay
/// consistent (AGENTS.md §1 `constants`).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Tabular (fixed-width) figures so columns of numbers line up in tables,
/// reports and KPI cards. Apply to a numeric [TextStyle]'s `fontFeatures`.
const List<FontFeature> tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// A square gap for `Row`/`Column` children — a lighter, self-documenting
/// alternative to scattering `SizedBox` with magic numbers.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
