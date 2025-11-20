import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';

class GetBookingStatus {
  final BookingRepository repo;
  GetBookingStatus(this.repo);

  Future<Booking> call(String bookingId) => repo.getBookingStatus(bookingId);
}
