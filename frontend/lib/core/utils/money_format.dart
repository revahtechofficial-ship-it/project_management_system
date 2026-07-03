// Money helpers (AGENTS.md §1 `core/utils`). Amounts are stored as integer
// cents throughout the app; these render them for display.

/// Formats an amount in cents as `$1,250.00`, with thousands separators.
String formatCents(int cents) {
  final bool negative = cents < 0;
  final String fixed = (cents.abs() / 100).toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String whole = parts[0];
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(whole[i]);
  }
  return '${negative ? '-' : ''}\$$grouped.${parts[1]}';
}
