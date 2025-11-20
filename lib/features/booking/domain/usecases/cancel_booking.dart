import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';

class CancelBooking {
  final BookingRepository repo;
  CancelBooking(this.repo);

  Future<void> call(String bookingId) => repo.cancelBooking(bookingId);
}
