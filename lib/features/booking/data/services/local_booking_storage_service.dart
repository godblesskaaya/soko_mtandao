import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';

class LocalBookingStorage {
  static const _storageKey = 'anonymous_booking_history';

  Future<void> saveBooking(BookingModel booking) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get existing history
    final List<String> rawList = prefs.getStringList(_storageKey) ?? [];
    
    // 2. Avoid Duplicates: Check if this booking ID is already saved
    final exists = rawList.any((item) {
      final Map<String, dynamic> json = jsonDecode(item);
      return json['id'] == booking.id;
    });

    if (exists) return; // Don't save again if it exists

    // 3. Add new booking to the TOP of the list (newest first)
    rawList.insert(0, jsonEncode(booking.toJson()));

    // 4. Save back to storage
    await prefs.setStringList(_storageKey, rawList);
  }

  Future<List<Booking>> getLocalBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_storageKey) ?? [];

    // print debug info
    print('Retrieved ${rawList.length} bookings from local storage.');
    print('Raw data: $rawList');

    final List<Booking> bookings = [];
    for (var i=0; i<rawList.length; i++) {
      final item = rawList[i];

      try {
        final Map<String, dynamic> json = jsonDecode(item);
        print(  'decoded json type: ${json.runtimeType}');
        print('decoded json content: ${json.keys}');
        print('decoded jsonvalues: ${json.values}');

        final booking = BookingModel.fromJson(json);
        print('successfully parsed booking with id: ${booking.id}');
        bookings.add(booking);
      } catch (e, stackTrace) {
        // If parsing fails, skip this entry
        print('Failed to parse booking from local storage: $e');
        print('Stack trace: $stackTrace');
      }
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