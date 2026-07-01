/// Responsive layout breakpoints (logical pixels), centralised so the whole
/// app switches layouts at the same widths (AGENTS.md §1 `constants`).
abstract final class AppBreakpoints {
  /// Phones. Below this the UI is single-column.
  static const double compact = 600;

  /// Small tablets / split views. The shell switches from a drawer to a
  /// persistent sidebar at or above this width.
  static const double medium = 900;

  /// Large tablets / small laptops. Below this the persistent sidebar shows
  /// as an icon rail; at or above it, the full labelled sidebar.
  static const double expanded = 1200;
}
