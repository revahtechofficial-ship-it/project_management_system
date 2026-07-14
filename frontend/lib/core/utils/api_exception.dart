import 'package:dio/dio.dart';

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

/// Turns anything we might catch into a sentence worth showing somebody.
///
/// The API already answers a failure with `{"error": "the event must end after
/// it starts"}` — a plain sentence, written for a person. Interpolating the
/// exception instead (`'Could not save: $e'`) throws that away and prints
/// Dio's several-hundred-character diagnostic, which tells the reader nothing
/// they can act on and buries the one line that would have.
///
/// So: use the server's words when it gave us any, and a short honest fallback
/// when it did not.
String describeError(Object? error) {
  if (error == null) {
    return 'Something went wrong.';
  }
  if (error is String) {
    return error;
  }
  if (error is ApiException) {
    return error.message;
  }
  if (error is DioException) {
    final Object? data = error.response?.data;
    if (data is Map && data['error'] is String) {
      final String message = (data['error'] as String).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    // No body, or a body we did not write — say what actually happened rather
    // than dumping the stack.
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'The server took too long to answer.',
      DioExceptionType.connectionError =>
        'Could not reach the server. Check your connection.',
      DioExceptionType.badResponse => switch (error.response?.statusCode) {
        401 => 'You are not signed in.',
        403 => 'You do not have permission to do that.',
        404 => 'That is not there any more.',
        409 => 'That already exists.',
        final int code? when code >= 500 =>
          'The server had a problem. Try again shortly.',
        _ => 'The server rejected that request.',
      },
      DioExceptionType.cancel => 'Cancelled.',
      _ => 'Something went wrong.',
    };
  }
  return error.toString();
}
