import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';


class Booking {
  final String id;
  final BookingCart bookingCart;
  final UserInfo user;

  final BookingStatusEnum status;
  final PaymentStatusEnum paymentStatus;

  final String? ticketNumber;
  final double? totalPrice; // optional snapshot from backend

  Booking({
    required this.id,
    required this.bookingCart,
    required this.user,
    required this.status,
    required this.paymentStatus,
    this.ticketNumber,
    this.totalPrice,
  });
  
}
