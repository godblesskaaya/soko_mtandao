import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';

class BookingSearchResult {
  final Booking? booking;
  final bool found;

  BookingSearchResult({
    required this.booking,
    required this.found,
  });
}
