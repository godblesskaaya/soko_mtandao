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
  final double? amountPaid;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paymentInitiatedAt;
  final DateTime? providerGraceExpiresAt;
  final DateTime? paymentCompletedAt;
  final String rawStatus;
  final String rawPaymentStatus;
  final String reconciliationStatus;
  final Map<String, dynamic>? latestPayment;

  Booking({
    required this.id,
    required this.bookingCart,
    required this.user,
    required this.status,
    required this.paymentStatus,
    this.ticketNumber,
    this.totalPrice,
    this.amountPaid,
    this.createdAt,
    this.expiresAt,
    this.paymentInitiatedAt,
    this.providerGraceExpiresAt,
    this.paymentCompletedAt,
    this.rawStatus = 'pending',
    this.rawPaymentStatus = 'initiated',
    this.reconciliationStatus = 'none',
    this.latestPayment,
  });
}
