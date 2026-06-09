/// Thrown when an API response is missing or has an unexpected shape.
///
/// A project-specific exception (AGENTS.md §6, "use custom exceptions"),
/// used by repositories to avoid `!` non-null assertions on response bodies.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}
