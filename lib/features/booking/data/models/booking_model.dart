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
    super.amountPaid,
    super.createdAt,
    super.expiresAt,
    super.paymentInitiatedAt,
    super.providerGraceExpiresAt,
    super.paymentCompletedAt,
    super.rawStatus,
    super.rawPaymentStatus,
    super.reconciliationStatus,
    super.latestPayment,
    required super.bookingCart,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseServerDate(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      if (raw.isEmpty) return null;

      // PostgreSQL timestamps without timezone are returned without offset.
      // Treat them as UTC to avoid local-time drift in expiry calculations.
      final hasOffset =
          raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
      final normalized = hasOffset ? raw : '${raw}Z';
      return DateTime.tryParse(normalized)?.toLocal();
    }

    BookingStatusEnum toBookingStatus(String? s) {
      switch (s) {
        case 'pending':
        case 'payment_reconciliation':
          return BookingStatusEnum.pending;
        case 'confirmed':
          return BookingStatusEnum.confirmed;
        case 'cancelled':
        case 'expired':
          return BookingStatusEnum.cancelled;
        default:
          return BookingStatusEnum.pending;
      }
    }

    PaymentStatusEnum toPaymentStatus(String? s) {
      switch (s) {
        case 'initiated':
          return PaymentStatusEnum.initiated;
        case 'pending':
        case 'pending_provider':
          return PaymentStatusEnum.pending;
        case 'unpaid':
          return PaymentStatusEnum.pending;
        case 'completed':
          return PaymentStatusEnum.completed;
        case 'failed':
          return PaymentStatusEnum.failed;
        default:
          return PaymentStatusEnum.initiated;
      }
    }

    return BookingModel(
      id: json['id'].toString(),
      user: UserModel.fromJson(json['user_data']),
      status: toBookingStatus(json['status']),
      paymentStatus: toPaymentStatus(json['payment_status']),
      ticketNumber: json['ticket_number'],
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      amountPaid: (json['amount_paid'] as num?)?.toDouble(),
      bookingCart: BookingCartModel.fromJson(json['cart']),
      createdAt: parseServerDate(json['created_at']),
      expiresAt: parseServerDate(json['expires_at']),
      paymentInitiatedAt: parseServerDate(json['payment_initiated_at']),
      providerGraceExpiresAt: parseServerDate(
        json['provider_grace_expires_at'],
      ),
      paymentCompletedAt: parseServerDate(json['payment_completed_at']),
      rawStatus: json['status']?.toString() ?? 'pending',
      rawPaymentStatus: json['payment_status']?.toString() ?? 'initiated',
      reconciliationStatus: json['reconciliation_status']?.toString() ?? 'none',
      latestPayment: json['latest_payment'] is Map
          ? Map<String, dynamic>.from(json['latest_payment'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_data': UserModel.fromEntity(user).toJson(),
    'status': status.name,
    'payment_status': paymentStatus.name,
    'ticket_number': ticketNumber,
    'total_price': totalPrice,
    'amount_paid': amountPaid,
    'cart': BookingCartModel.fromEntity(bookingCart).toJson(),
    'created_at': createdAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'payment_initiated_at': paymentInitiatedAt?.toIso8601String(),
    'provider_grace_expires_at': providerGraceExpiresAt?.toIso8601String(),
    'payment_completed_at': paymentCompletedAt?.toIso8601String(),
    'status_raw': rawStatus,
    'payment_status_raw': rawPaymentStatus,
    'reconciliation_status': reconciliationStatus,
    'latest_payment': latestPayment,
  };

  factory BookingModel.fromEntity(Booking booking) {
    return BookingModel(
      id: booking.id,
      user: UserModel.fromEntity(booking.user),
      status: booking.status,
      paymentStatus: booking.paymentStatus,
      ticketNumber: booking.ticketNumber,
      totalPrice: booking.totalPrice,
      amountPaid: booking.amountPaid,
      bookingCart: BookingCartModel.fromEntity(booking.bookingCart),
      createdAt: booking.createdAt,
      expiresAt: booking.expiresAt,
      paymentInitiatedAt: booking.paymentInitiatedAt,
      providerGraceExpiresAt: booking.providerGraceExpiresAt,
      paymentCompletedAt: booking.paymentCompletedAt,
      rawStatus: booking.rawStatus,
      rawPaymentStatus: booking.rawPaymentStatus,
      reconciliationStatus: booking.reconciliationStatus,
      latestPayment: booking.latestPayment,
    );
  }
}
