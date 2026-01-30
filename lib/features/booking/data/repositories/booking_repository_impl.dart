import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';
import '../datasources/booking_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingDataSource ds;
  BookingRepositoryImpl(this.ds);

  @override
  Future<Booking> initiateBooking({required BookingCart cart, required UserInfo user, required String sessionId}) {
    return ds.initiateBooking(user: UserModel.fromEntity(user), cart: BookingCartModel.fromEntity(cart), sessionId: sessionId);
  }

  @override
  Future<Booking> getBooking(String bookingId) => ds.getBooking(bookingId);

  @override
  Future<Booking> getBookingStatus(String bookingId) => ds.getBookingStatus(bookingId);

  @override
  Stream<Booking> monitorBookingPayment(String bookingId) => ds.monitorBookingPayment(bookingId);

  @override
  Future<void> cancelBooking(String bookingId) => ds.cancelBooking(bookingId);

  @override
  Future<BookingSearchResult> findBookingById(String bookingId) {
    // find the booking by id
    return ds.findBookingById(bookingId);
  }
}
