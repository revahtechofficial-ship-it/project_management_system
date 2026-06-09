/// Reusable `String` extensions (AGENTS.md §1 `core/extensions`).
extension StringCasing on String {
  /// Capitalizes the first character, leaving the rest unchanged.
  ///
  /// Used by enum `label` getters in `lib/data/enums/` (AGENTS.md §9).
  String get inCaps =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
