import 'package:soko_mtandao/core/errors/failures.dart';

/// Converts arbitrary runtime errors into user-safe messages.
String userMessageForError(Object error) {
  final raw = error is Failure ? error.message : error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('invalid ticket number')) {
    return 'Invalid booking ticket. Please use the latest booking reference.';
  }

  if (lower.contains('unauthorized booking access')) {
    return 'You are not allowed to access this booking. Use the correct account or booking ticket.';
  }

  if (lower.contains('authentication required for this booking')) {
    return 'This booking requires account sign-in or a valid booking ticket.';
  }

  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('timeout') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('errno') ||
      lower.contains('uri=')) {
    return 'Network issue detected. Please check your connection and try again.';
  }

  if (lower.contains('email not confirmed') ||
      lower.contains('confirm your email')) {
    return 'Please confirm your email address, then log in.';
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
    return 'An account already exists for this email. Log in or reset your password.';
  }

  if (lower.contains('weak password') ||
      lower.contains('password should') ||
      lower.contains('password requirements')) {
    return 'Use at least 8 characters with uppercase, lowercase, and a number.';
  }

  if (lower.contains('account is suspended') ||
      lower.contains('account is frozen')) {
    return 'This account is suspended. Contact support for help.';
  }

  if (lower.contains('complete your manager profile')) {
    return 'Complete your manager profile before submitting.';
  }

  if (lower.contains('submit kyc')) {
    return 'Submit KYC before sending a hotel manager application.';
  }

  if (lower.contains('invalid invite token') ||
      lower.contains('invite not found')) {
    return 'Invalid invite token. Check the token and try again.';
  }

  if (lower.contains('invite has expired')) {
    return 'This invite has expired. Ask your manager for a new one.';
  }

  if (lower.contains('different email address')) {
    return 'This invite belongs to a different email address.';
  }

  if (lower.contains('rate limit') ||
      lower.contains('over_email_send_rate_limit')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }

  if (lower.contains('invalid login credentials') ||
      lower.contains('auth') ||
      lower.contains('unauthorized')) {
    return 'Authentication failed. Please verify your credentials and try again.';
  }

  if (lower.contains('not found')) {
    return 'Requested data was not found.';
  }

  if (lower.contains('conflict')) {
    return 'This action conflicts with existing data. Please review and try again.';
  }

  if (lower.contains('permission') || lower.contains('forbidden')) {
    return 'You do not have permission to perform this action.';
  }

  // Keep explicit user-safe failures, but strip technical detail tails when present.
  if (error is Failure) {
    final separatorIndex = raw.indexOf(':');
    if (separatorIndex > 0 && raw.toLowerCase().startsWith('failed to ')) {
      return raw.substring(0, separatorIndex);
    }
    return raw;
  }

  return 'Something went wrong. Please try again.';
}
