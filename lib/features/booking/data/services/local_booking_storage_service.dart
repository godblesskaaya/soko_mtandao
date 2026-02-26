import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';

class LocalBookingStorage {
  static const _storageKey = 'anonymous_booking_history';

  Future<void> saveBooking(BookingModel booking) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Get existing history
    final List<String> rawList = prefs.getStringList(_storageKey) ?? [];

    // 2. Upsert by booking id so pending/confirmed status can be refreshed.
    final encoded = jsonEncode(booking.toJson());
    final existingIndex = rawList.indexWhere((item) {
      final Map<String, dynamic> json = jsonDecode(item);
      return json['id'] == booking.id;
    });

    if (existingIndex >= 0) {
      rawList.removeAt(existingIndex);
    }

    // 3. Add latest record to top (newest first).
    rawList.insert(0, encoded);

    // 4. Save back to storage.
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<List<Booking>> getLocalBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_storageKey) ?? [];

    final List<Booking> bookings = [];
    final List<String> cleanedRawList = [];
    bool didPruneExpired = false;
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];

      try {
        final Map<String, dynamic> json = jsonDecode(item);
        final booking = BookingModel.fromJson(json);

        final isPendingUnpaid = booking.status == BookingStatusEnum.pending &&
            booking.paymentStatus == PaymentStatusEnum.pending;
        final isExpired = booking.expiresAt != null &&
            DateTime.now().isAfter(booking.expiresAt!);

        // Remove pending expired bookings from local history.
        if (isPendingUnpaid && isExpired) {
          didPruneExpired = true;
          continue;
        }

        bookings.add(booking);
        cleanedRawList.add(item);
      } catch (e, stackTrace) {
        ErrorReporter.report(
          e,
          stackTrace,
          source: 'local_booking_storage.getLocalBookings',
          context: {'index': i},
        );
      }
    }

    if (didPruneExpired || cleanedRawList.length != rawList.length) {
      await prefs.setStringList(_storageKey, cleanedRawList);
    }

    return bookings;
  }

  // Optional: Clear history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

// Create a simple provider for this service
final localBookingStorageProvider = Provider((ref) => LocalBookingStorage());

// Create a FutureProvider to fetch the list for your "My History" screen
final localBookingHistoryProvider = FutureProvider<List<Booking>>((ref) async {
  final storage = ref.watch(localBookingStorageProvider);
  return storage.getLocalBookings();
});
