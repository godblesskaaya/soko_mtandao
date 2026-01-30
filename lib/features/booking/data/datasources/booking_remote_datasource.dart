import 'dart:async';

import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking_conflict_exception.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_datasource.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';

class BookingRemoteDataSource implements BookingDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<BookingModel> initiateBooking({
    required UserModel user,
    required BookingCartModel cart,
    required String sessionId,
  }) async {
    // Payload shape matches your backend RPC contract
    final payload = {
      'user_data': user.toJson(),
      'cart': cart.bookings.map((b) => {
        'hotel_id': b.hotel.id,
        'start_date': b.startDate.toIso8601String(),
        'end_date': b.endDate.toIso8601String(),
        'items': b.items.map((i) => {
          'offering_id': i.offering.id,
          'room_id': i.room.id,
          'price_per_night': i.offering.pricePerNight,
        }).toList(),
      }).toList(),
      'p_session_id': sessionId,
    };

    // log the payload for debugging
    print('Booking initiation payload: $payload');

    // Example RPC (you can swap to REST or table insert)
    final res = await _client.rpc('create_booking', params: payload);

    // log the response for debugging
    print('Booking initiation response: $res');
    
    // Defensive checks — handle variable response shape
    if (res is Map<String, dynamic>) {
      final success = res['success'] == true;

      if (success && res['booking'] != null) {
        // Success path → parse booking
        return BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
      } else {
        // Failure path → room conflicts or validation errors
        final message = res['message'] ?? 'Booking failed.';
        final conflicts = (res['conflicts'] as List?) ?? [];

        throw BookingConflictException(
          message: message,
          conflicts: conflicts.map((c) => BookingConflict.fromJson(c)).toList(),
        );
      }
    }

    // If response shape is unexpected
    throw Exception('Unexpected response from server');
  }

  @override
  Future<BookingModel> getBooking(String bookingId) async {
    final res = await _client
        .rpc("get_booking_details", params: {'p_booking_id': bookingId});
    print("fetched booking by getbooking method: $res");
    if (res == null || res['success'] != true) {
      throw Exception('Failed to load booking: Booking not found');
    }

    return BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
  }

  @override
  Future<BookingModel> getBookingStatus(String bookingId) async {
    final res = await _client
        .from('bookings') // or RPC
        .select()
        .eq('id', bookingId)
        .single();
    return BookingModel.fromJson(res);
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _client.rpc('bookings_cancel', params: {'booking_id': bookingId});
  }

  @override
  Future<BookingSearchResult> findBookingById(String bookingId) {
    // find the booking by id
    return _client
        .rpc("get_booking_details", params: {'p_booking_id': bookingId})
        .then((res) {
          if (res != null && res['success'] == true) {
            return BookingSearchResult(booking: BookingModel.fromJson(res['booking']), found: true);
          } else {
            return BookingSearchResult(booking: null, found: false);
          }
        });
  }

  // extension for this file
  @override
  Stream<BookingModel> monitorBookingPayment(String bookingId) {
    final controller = StreamController<BookingModel>();

    Future<void> fetchAndEmit() async {
      try {
        final res = await _client
            .rpc('get_booking_details', params: {'p_booking_id': bookingId});
        print('Fetched booking update: ${res.toString()}');

        // Defensive checks — handle variable response shape
        if (res is Map<String, dynamic>) {
          final success = res['success'] == true;
          final booking = res['booking'];

          if (success && booking is Map<String, dynamic>) {
            // Success path → parse booking
            controller.add(BookingModel.fromJson(booking));
            return;
          } else {
            // Failure path → log error
            final message = res['message'] ?? 'Failed to fetch booking update.';
            throw Exception(message);
          }
        } else {
          // If response shape is unexpected
          throw Exception('Unexpected response from server ${res.runtimeType}');
        }
      } catch (e, stackTrace) {
        print('Error fetching booking update: $e');
        print('Stack trace: $stackTrace');
        controller.addError(e);
      }
    }

    // 1️⃣ Emit initial snapshot
    fetchAndEmit();

    // 2️⃣ Realtime listener
    final channel = _client
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: bookingId),
          // callback: (payload) {
          //   final newRecord = payload.newRecord;
          //   // if (newRecord != null && newRecord['id'] == bookingId) {
          //     controller.add(BookingModel.fromJson(newRecord));
          //   // }
          // },

          // callback function to recall fetchAndEmit
          callback: (payload) => fetchAndEmit(),
        )
        .subscribe();

    // 3️⃣ Polling fallback
    final timer = Timer.periodic(AppConfig.paymentPollInterval, (_) {
      fetchAndEmit();
    });

    controller.onCancel = () {
      _client.removeChannel(channel);
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
