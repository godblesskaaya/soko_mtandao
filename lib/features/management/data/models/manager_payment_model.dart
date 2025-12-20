import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'dart:convert';

class ManagerPaymentModel extends ManagerPayment {
  const ManagerPaymentModel({
    required super.paymentId,
    required super.amount,
    required super.currency,
    required super.paymentStatus,
    required super.paymentType,
    super.externalId,
    super.paymentGatewayRef,
    required super.paymentCreatedAt,
    required super.paymentUpdatedAt,
    super.paymentMetadata,
    super.azampayResponse,
    super.verifiedBy,
    required super.bookingId,
    super.hotelId,
    super.ticketNumber,
    super.customerName,
    super.customerPhone,
    super.customerEmail,
    super.bookingTotalPrice,
    super.bookingStatus,
  });

  factory ManagerPaymentModel.fromJson(Map<String, dynamic> json) {
    //log the json received
    print('ManagerPaymentModel.fromJson: $json');
    // Helper function to handle JSON types that need conversion
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // JSON fields from the view (database column names)
    return ManagerPaymentModel(
      // Payment Details
      paymentId: json['payment_id'] as String,
      amount: parseDouble(json['amount']) ?? 0.0, // Use 0.0 as a safe default
      currency: json['currency'] as String,
      paymentStatus: json['payment_status'] as String,
      paymentType: (json['payment_type'] as String?) ?? 'N/A',
      externalId: json['external_id'] as String?,
      paymentGatewayRef: json['payment_gateway_ref'] as String?,
      paymentCreatedAt: DateTime.parse(json['payment_created_at'] as String),
      paymentUpdatedAt: DateTime.parse(json['payment_updated_at'] as String),
      
      // JSONB fields are often transmitted as decoded Map<String, dynamic> or sometimes as raw String
      paymentMetadata: (json['payment_metadata'] is String && (json['payment_metadata'] as String).isNotEmpty) 
          ? jsonDecode(json['payment_metadata'] as String) as Map<String, dynamic>
          : json['payment_metadata'] as Map<String, dynamic>?,
      
      azampayResponse: (json['azampay_response'] is String && (json['azampay_response'] as String).isNotEmpty) 
          ? jsonDecode(json['azampay_response'] as String) as Map<String, dynamic>
          : json['azampay_response'] as Map<String, dynamic>?,
          
      verifiedBy: json['verified_by'] as String?,
      
      // Booking Details
      bookingId: json['booking_id'] as String,
      hotelId: json['hotel_id'] as String?,
      ticketNumber: json['ticket_number'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      bookingTotalPrice: parseDouble(json['booking_total_price']),
      bookingStatus: json['booking_status'] as String?,
    );
  }

}