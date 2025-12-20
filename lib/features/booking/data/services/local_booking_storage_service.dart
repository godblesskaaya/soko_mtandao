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

    return rawList
        .map((item) => BookingModel.fromJson(jsonDecode(item)))
        .toList();
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