import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';

class GetBooking {
  final BookingRepository repo;
  GetBooking(this.repo);

  Future<Booking> call(String bookingId) => repo.getBooking(bookingId);
}
