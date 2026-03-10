import 'dart:async';

import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_datasource.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking_conflict_exception.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingRemoteDataSource implements BookingDataSource {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalBookingStorage _localStorage = LocalBookingStorage();
  static final Map<String, String> _ticketCache = <String, String>{};

  Future<String?> _resolveTicket(String bookingId) async {
    final fromCache = _ticketCache[bookingId];
    if (fromCache != null && fromCache.trim().isNotEmpty) return fromCache;

    final localBookings = await _localStorage.getLocalBookings();
    for (final booking in localBookings) {
      if (booking.id == bookingId &&
          (booking.ticketNumber ?? '').trim().isNotEmpty) {
        final ticket = booking.ticketNumber!.trim();
        _ticketCache[bookingId] = ticket;
        return ticket;
      }
    }

    return null;
  }

  void _cacheTicket(BookingModel booking) {
    final ticket = (booking.ticketNumber ?? '').trim();
    if (ticket.isNotEmpty) {
      _ticketCache[booking.id] = ticket;
    }
  }

  @override
  Future<BookingModel> initiateBooking({
    required UserModel user,
    required BookingCartModel cart,
    required String sessionId,
  }) async {
    final payload = {
      'user_data': user.toJson(),
      'cart': cart.bookings
          .map((b) => {
                'hotel_id': b.hotel.id,
                'start_date': formatYmd(b.startDate),
                'end_date': formatYmd(b.endDate),
                'items': b.items
                    .map((i) => {
                          'offering_id': i.offering.id,
                          'room_id': i.room.id,
                          'price_per_night': i.offering.pricePerNight,
                        })
                    .toList(),
              })
          .toList(),
      'p_session_id': sessionId,
    };

    final res = await _client.rpc('create_booking', params: payload);

    if (res is Map<String, dynamic>) {
      final success = res['success'] == true;

      if (success && res['booking'] != null) {
        final booking =
            BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
        _cacheTicket(booking);
        return booking;
      }

      final message = res['message'] ?? 'Booking failed.';
      final conflicts = (res['conflicts'] as List?) ?? [];
      throw BookingConflictException(
        message: message,
        conflicts: conflicts.map((c) => BookingConflict.fromJson(c)).toList(),
      );
    }

    throw Exception('Unexpected response from server');
  }

  @override
  Future<BookingModel> getBooking(String bookingId) async {
    final ticket = await _resolveTicket(bookingId);
    final params = <String, dynamic>{'p_booking_id': bookingId};
    if (ticket != null) params['p_ticket_number'] = ticket;

    final res = await _client.rpc('get_booking_details_secure', params: params);
    if (res == null || res['success'] != true) {
      throw Exception('Failed to load booking: Booking not found');
    }

    final booking =
        BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
    _cacheTicket(booking);
    return booking;
  }

  @override
  Future<BookingModel> getBookingStatus(String bookingId) async {
    final ticket = await _resolveTicket(bookingId);
    final params = <String, dynamic>{'p_booking_id': bookingId};
    if (ticket != null) params['p_ticket_number'] = ticket;

    final res = await _client.rpc('get_booking_details_secure', params: params);
    if (res == null || res['success'] != true) {
      throw Exception('Failed to load booking status');
    }

    final booking =
        BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
    _cacheTicket(booking);
    return booking;
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _client.rpc('bookings_cancel', params: {'booking_id': bookingId});
  }

  @override
  Future<BookingSearchResult> findBookingById(String bookingId) {
    return _client.rpc('get_booking_details_by_ticket',
        params: {'p_ticket_number': bookingId}).then((res) {
      if (res != null && res['success'] == true) {
        final booking =
            BookingModel.fromJson(res['booking'] as Map<String, dynamic>);
        _cacheTicket(booking);
        return BookingSearchResult(booking: booking, found: true);
      }
      return BookingSearchResult(booking: null, found: false);
    });
  }

  @override
  Stream<BookingModel> monitorBookingPayment(String bookingId) {
    final controller = StreamController<BookingModel>();

    Future<void> fetchAndEmit() async {
      try {
        final ticket = await _resolveTicket(bookingId);
        final params = <String, dynamic>{'p_booking_id': bookingId};
        if (ticket != null) params['p_ticket_number'] = ticket;

        final res =
            await _client.rpc('get_booking_details_secure', params: params);

        if (res is Map<String, dynamic>) {
          final success = res['success'] == true;
          final booking = res['booking'];

          if (success && booking is Map<String, dynamic>) {
            final model = BookingModel.fromJson(booking);
            _cacheTicket(model);
            controller.add(model);
            return;
          }

          final message = res['message'] ?? 'Failed to fetch booking update.';
          throw Exception(message);
        }

        throw Exception('Unexpected response from server ${res.runtimeType}');
      } catch (e, stackTrace) {
        ErrorReporter.report(
          e,
          stackTrace,
          source: 'booking_remote.monitorBookingPayment',
          context: {'bookingId': bookingId},
        );
        controller.addError(e);
      }
    }

    fetchAndEmit();

    final channel = _client
        .channel('public:bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (_) => fetchAndEmit(),
        )
        .subscribe();

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
