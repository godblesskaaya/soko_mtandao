import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/errors/failure_mapper.dart';

void main() {
  group('failureFromError', () {
    test('surfaces duplicate signup emails before generic auth failures', () {
      final failure = failureFromError(
        'AuthApiException: Email already in use',
      );

      expect(
        failure.message,
        'An account already exists for this email. Log in or reset your password.',
      );
    });
  });
}
