import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';


class InitiateBooking {
  final BookingRepository repo;
  InitiateBooking(this.repo);

  Future<Booking> call({required UserInfo user, required BookingCart cart}) {
    return repo.initiateBooking(user: user, cart: cart);
  }
}
