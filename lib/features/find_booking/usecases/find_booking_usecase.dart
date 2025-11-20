import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';

class FindBookingUseCase {
  final BookingRepository repository;

  FindBookingUseCase(this.repository);

  Future<BookingSearchResult> call(String bookingId) {
    return repository.findBookingById(bookingId);
  }
}
