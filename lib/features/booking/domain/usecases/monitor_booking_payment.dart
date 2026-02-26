import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class MonitorBookingPayment {
  final BookingRepository repository;
  MonitorBookingPayment(this.repository);

  Stream<Booking> call(String bookingId) =>
      repository.monitorBookingPayment(bookingId);
}
