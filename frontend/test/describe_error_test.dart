import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/api_exception.dart';

DioException _badResponse(int status, Object? body) {
  final RequestOptions options = RequestOptions(path: '/api/v1/events');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('the server wrote a sentence, so use it', () {
    test('lifts the error message out of the body', () {
      // This is the exact 400 the calendar was throwing away.
      final DioException e = _badResponse(400, <String, dynamic>{
        'error': 'the event must end after it starts',
      });
      expect(describeError(e), 'the event must end after it starts');
    });

    test('does not leak Dio diagnostics into the message', () {
      final DioException e = _badResponse(400, <String, dynamic>{
        'error': 'a title is required',
      });
      final String message = describeError(e);
      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('validateStatus')));
      expect(message, isNot(contains('status code')));
      expect(message.length, lessThan(80));
    });
  });

  group('when the server said nothing useful', () {
    test('a status code becomes a sentence, not a number', () {
      expect(describeError(_badResponse(401, null)), 'You are not signed in.');
      expect(
        describeError(_badResponse(403, null)),
        'You do not have permission to do that.',
      );
      expect(
        describeError(_badResponse(404, null)),
        'That is not there any more.',
      );
      expect(describeError(_badResponse(409, null)), 'That already exists.');
      expect(
        describeError(_badResponse(500, null)),
        'The server had a problem. Try again shortly.',
      );
    });

    test('a body of the wrong shape falls back rather than throwing', () {
      expect(describeError(_badResponse(400, 'plain text')), isNotEmpty);
      expect(describeError(_badResponse(400, <String, dynamic>{})), isNotEmpty);
      expect(
        describeError(_badResponse(400, <String, dynamic>{'error': 42})),
        isNotEmpty,
      );
      // An empty message is not a message.
      expect(
        describeError(_badResponse(400, <String, dynamic>{'error': '   '})),
        'The server rejected that request.',
      );
    });

    test('a network failure says so', () {
      final DioException offline = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect(describeError(offline), contains('Could not reach the server'));

      final DioException slow = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.receiveTimeout,
      );
      expect(describeError(slow), contains('too long'));
    });
  });

  group('everything else', () {
    test('a String passes through, so old call sites still work', () {
      expect(describeError('A title is required'), 'A title is required');
    });

    test('an ApiException uses its own message', () {
      expect(describeError(const ApiException('bad shape')), 'bad shape');
    });

    test('null does not print "null"', () {
      expect(describeError(null), 'Something went wrong.');
    });

    test('an unknown error still yields something', () {
      expect(describeError(StateError('boom')), contains('boom'));
    });
  });
}
