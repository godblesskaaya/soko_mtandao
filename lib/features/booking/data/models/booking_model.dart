import 'package:soko_mtandao/features/booking/data/models/user_model.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_cart_model.dart';

class BookingModel extends Booking {
  BookingModel({
    required super.id,
    required super.user,
    required super.status,
    required super.paymentStatus,
    super.ticketNumber,
    super.totalPrice,
    required super.bookingCart,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    BookingStatusEnum _toBookingStatus(String? s) {
      switch (s) {
        case 'pending': return BookingStatusEnum.pending;
        case 'confirmed': return BookingStatusEnum.confirmed;
        case 'cancelled': return BookingStatusEnum.cancelled;
        default: return BookingStatusEnum.pending;
      }
    }

    PaymentStatusEnum _toPaymentStatus(String? s) {
      switch (s) {
        case 'initiated': return PaymentStatusEnum.initiated;
        case 'pending': return PaymentStatusEnum.pending;
        case 'completed': return PaymentStatusEnum.completed;
        case 'failed': return PaymentStatusEnum.failed;
        default: return PaymentStatusEnum.initiated;
      }
    }

    return BookingModel(
      id: json['id'].toString(),
      user: UserModel.fromJson(json['user_data']),
      status: _toBookingStatus(json['status']),
      paymentStatus: _toPaymentStatus(json['payment_status']),
      ticketNumber: json['ticket_number'],
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      bookingCart: BookingCartModel.fromJson(json['cart']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_data': UserModel.fromEntity(user).toJson(),
    'status': status.name,
    'payment_status': paymentStatus.name,
    'ticket_number': ticketNumber,
    'total_price': totalPrice,
    'cart': BookingCartModel.fromEntity(bookingCart).toJson(),
  };

  factory BookingModel.fromEntity(Booking booking) {
    return BookingModel(
      id: booking.id,
      user: UserModel.fromEntity(booking.user),
      status: booking.status,
      paymentStatus: booking.paymentStatus,
      ticketNumber: booking.ticketNumber,
      totalPrice: booking.totalPrice,
      bookingCart: BookingCartModel.fromEntity(booking.bookingCart),
    );
  }
}
