
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';

abstract class BookingDataSource {
  Future<BookingModel> initiateBooking({
    required UserModel user,
    required BookingCartModel cart,
  });

  Future<BookingModel> getBooking(String bookingId);

  Future<BookingModel> getBookingStatus(String bookingId);

  Future<void> cancelBooking(String bookingId);

  Future<BookingSearchResult> findBookingById(String bookingId);

  Stream<BookingModel> monitorBookingPayment(String bookingId);
}
