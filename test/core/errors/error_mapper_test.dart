import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';

void main() {
  group('userMessageForError', () {
    test('surfaces email confirmation recovery', () {
      expect(
        userMessageForError('AuthException: Email not confirmed'),
        'Please confirm your email address, then log in.',
      );
    });

    test('surfaces manager onboarding blockers', () {
      expect(
        userMessageForError(
          'PostgrestException: Complete your manager profile before submitting',
        ),
        'Complete your manager profile before submitting.',
      );
      expect(
        userMessageForError(
          'PostgrestException: Submit KYC before sending a hotel manager application',
        ),
        'Submit KYC before sending a hotel manager application.',
      );
    });

    test('surfaces staff invite blockers', () {
      expect(
        userMessageForError('PostgrestException: Invalid invite token'),
        'Invalid invite token. Check the token and try again.',
      );
      expect(
        userMessageForError('PostgrestException: Invite has expired'),
        'This invite has expired. Ask your manager for a new one.',
      );
    });
  });
}
