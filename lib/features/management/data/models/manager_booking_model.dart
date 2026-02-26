import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';

class ManagerBookingModel extends ManagerBooking {
  ManagerBookingModel({
    required String id,
    final String? hotelId,
    final String? customerName,
    final String? customerPhone,
    final String? customerEmail,
    final double? totalPrice,
    final String? status,
    final String? paymentStatus,
    final String? paymentType,
    final String? receiptUrl,
    final String? ticketNumber,
    final DateTime? createdAt,
  }) : super(
          id: id,
          hotelId: hotelId,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          totalPrice: totalPrice,
          status: status,
          paymentStatus: paymentStatus,
          paymentType: paymentType,
          receiptUrl: receiptUrl,
          ticketNumber: ticketNumber,
          createdAt: createdAt,
        );

  factory ManagerBookingModel.fromJson(Map<String, dynamic> json) {
    return ManagerBookingModel(
      id: json['id'],
      hotelId: json['hotel_id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      customerEmail: json['customer_email'],
      totalPrice: json['total_price']?.toDouble(),
      status: json['status'],
      paymentStatus: json['payment_status'],
      paymentType: json['payment_type'],
      receiptUrl: json['receipt_url'],
      ticketNumber: json['ticket_number'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  factory ManagerBookingModel.fromEntity(ManagerBooking booking) {
    return ManagerBookingModel(
      id: booking.id,
      hotelId: booking.hotelId,
      customerName: booking.customerName,
      customerPhone: booking.customerPhone,
      customerEmail: booking.customerEmail,
      totalPrice: booking.totalPrice,
      status: booking.status,
      paymentStatus: booking.paymentStatus,
      paymentType: booking.paymentType,
      receiptUrl: booking.receiptUrl,
      ticketNumber: booking.ticketNumber,
      createdAt: booking.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hotelId': hotelId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'totalPrice': totalPrice,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentType': paymentType,
      'receiptUrl': receiptUrl,
      'ticketNumber': ticketNumber,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

// 🚫 Removed: final List<BookingItem> items;
