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
