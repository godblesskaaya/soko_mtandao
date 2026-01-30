import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// TTL for the booking session
const _bookingSessionTtl = Duration(minutes: 15);

class BookingSession {
  final String id;
  final DateTime expiresAt;

  BookingSession({required this.id, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class BookingSessionNotifier extends StateNotifier<BookingSession> {
  BookingSessionNotifier() : super(_createNewSession());

  static BookingSession _createNewSession() {
    final now = DateTime.now();
    return BookingSession(
      id: const Uuid().v4(),
      expiresAt: now.add(_bookingSessionTtl),
    );
  }

  /// Returns the current session ID, regenerating if expired
  String get sessionId {
    if (state.isExpired) {
      state = _createNewSession();
    }
    return state.id;
  }

  /// Resets the session manually
  void reset() {
    state = _createNewSession();
  }
}

// The provider
final bookingSessionProvider =
    StateNotifierProvider<BookingSessionNotifier, BookingSession>(
        (ref) => BookingSessionNotifier());
