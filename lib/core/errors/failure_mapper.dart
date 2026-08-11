import 'package:soko_mtandao/core/errors/failures.dart';

Failure failureFromError(Object error) {
  if (error is Failure) return error;

  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('invalid ticket number')) {
    return ServerFailure(
      'Invalid booking ticket. Please use the latest booking reference.',
    );
  }

  if (lower.contains('unauthorized booking access')) {
    return ServerFailure(
      'You are not allowed to access this booking. Use the correct account or booking ticket.',
    );
  }

  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('timeout')) {
    return ServerFailure('Network issue detected. Please try again.');
  }

  final isDuplicateSignupEmail =
      lower.contains('email already') ||
      lower.contains('email address already') ||
      lower.contains('email is already') ||
      lower.contains('email already in use') ||
      lower.contains('email already registered') ||
      lower.contains('user already registered') ||
      lower.contains('user already exists') ||
      (lower.contains('email') && lower.contains('already registered')) ||
      (lower.contains('email') && lower.contains('already in use')) ||
      (lower.contains('email') && lower.contains('already exists'));

  if (isDuplicateSignupEmail) {
    return ServerFailure(
      'An account already exists for this email. Log in or reset your password.',
    );
  }

  if (lower.contains('auth') ||
      lower.contains('unauthorized') ||
      lower.contains('invalid login credentials')) {
    return ServerFailure('Authentication failed.');
  }

  if (lower.contains('not found')) {
    return ServerFailure('Requested resource was not found.');
  }

  if (lower.contains('permission') || lower.contains('forbidden')) {
    return ServerFailure('Permission denied.');
  }

  return ServerFailure('An unexpected error occurred.');
}
