import 'package:flutter/foundation.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/core/errors/failures.dart';

class ErrorReporter {
  static String? _lastSignature;
  static DateTime? _lastAt;

  static void report(
    Object error,
    StackTrace stack, {
    String source = 'app',
    Map<String, Object?> context = const {},
  }) {
    final message = error is Failure ? userMessageForError(error) : error.toString();
    final signature = '[$source][$message]';
    final now = DateTime.now();
    if (_lastSignature == signature &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastSignature = signature;
    _lastAt = now;

    debugPrint('[$source] $message');
    if (context.isNotEmpty) {
      debugPrint('[$source] context: $context');
    }
    debugPrintStack(stackTrace: stack);
  }
}
