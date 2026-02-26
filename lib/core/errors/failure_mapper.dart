import 'package:soko_mtandao/core/errors/failures.dart';

Failure failureFromError(Object error) {
  if (error is Failure) return error;

  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('timeout')) {
    return ServerFailure('Network issue detected. Please try again.');
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
