import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';

class ManagerBooking {
  final String id;
  final String? hotelId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double? totalPrice;
  final String? status;
  final String? paymentStatus;
  final String? paymentType;
  final String? receiptUrl;
  final String? ticketNumber;
  final DateTime? createdAt;

  ManagerBooking({
    required this.id,
    this.hotelId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.totalPrice,
    this.status,
    this.paymentStatus,
    this.paymentType,
    this.receiptUrl,
    this.ticketNumber,
    this.createdAt,
  });

}
