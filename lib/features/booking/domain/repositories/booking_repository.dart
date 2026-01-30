import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';

import '../entities/booking.dart';
import '../entities/user_info.dart';

abstract class BookingRepository {
  /// Initiates booking (validates availability + locks rooms)
  /// Returns created Booking with id.
  Future<Booking> initiateBooking({
    required UserInfo user,
    required BookingCart cart, // reuse your existing cart entity
    required String sessionId,
  });

  Future<Booking> getBooking(String bookingId);

  /// Poll or fetch fresh status
  Future<Booking> getBookingStatus(String bookingId);
  Stream<Booking> monitorBookingPayment(String bookingId);

  /// Optional cancel (release locks)
  Future<void> cancelBooking(String bookingId);

  Future<BookingSearchResult> findBookingById(String bookingId);
}
