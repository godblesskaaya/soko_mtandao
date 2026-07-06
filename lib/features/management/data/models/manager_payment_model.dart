import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';

class ManagerPaymentModel extends ManagerPayment {
  ManagerPaymentModel({
    required super.settlementId,
    required super.hotelId,
    required super.bookingId,
    required super.amount,
    required super.status,
    required super.date,
    required super.nights,
    required super.rate,
    required super.checkIn,
    required super.checkOut,
    required super.customerName,
    required super.customerPhone,
    required super.ticketNumber,
    required super.gatewayRef,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.paymentProviderStatus,
    required super.paymentReconciliationStatus,
    required super.bookingStatus,
    required super.bookingPaymentStatus,
    required super.bookingReconciliationStatus,
    required super.grossAmount,
    required super.commissionAmount,
    required super.taxAmount,
    required super.hotelNetAmount,
    required super.providerFeeAmount,
    required super.payoutStatus,
    required super.payoutProviderStatus,
    required super.payoutProviderReference,
    required super.payoutExternalReference,
    required super.roomNumber,
  });

  // data/models/manager_payment_model.dart
  factory ManagerPaymentModel.fromJson(Map<String, dynamic> json) {
    debugPrint("managerpayment returned from supabase $json");
    return ManagerPaymentModel(
      settlementId: json['settlement_id'],
      hotelId: json['hotel_id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      amount: (json['settled_amount'] as num).toDouble(),
      status: json['settlement_status'],
      date: DateTime.parse(json['settled_at']),
      roomNumber: json['room_number'],
      nights: json['total_nights'],
      rate: (json['price_per_night'] as num).toDouble(),
      checkIn: DateTime.parse(json['start_date']),
      checkOut: DateTime.parse(json['end_date']),
      customerName: json['customer_name'] ?? 'Unknown',
      customerPhone: json['customer_phone'] ?? '-',
      ticketNumber: json['ticket_number'] ?? '-',
      gatewayRef: json['payment_gateway_ref'] ?? '-',
      paymentMethod: json['payment_method'] ?? 'N/A',
      paymentStatus: json['payment_status'] ?? '-',
      paymentProviderStatus: json['payment_provider_status'] ?? '-',
      paymentReconciliationStatus: json['payment_reconciliation_status'] ?? '-',
      bookingStatus: json['booking_status'] ?? '-',
      bookingPaymentStatus: json['booking_payment_status'] ?? '-',
      bookingReconciliationStatus: json['booking_reconciliation_status'] ?? '-',
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      hotelNetAmount: (json['hotel_net_amount'] as num?)?.toDouble() ?? 0,
      providerFeeAmount: (json['provider_fee_amount'] as num?)?.toDouble() ?? 0,
      payoutStatus: json['payout_status'] ?? '-',
      payoutProviderStatus: json['payout_provider_status'] ?? '-',
      payoutProviderReference:
          json['payout_provider_reference'] ??
          json['payout_provider_batch_ref'] ??
          '-',
      payoutExternalReference:
          json['payout_provider_external_reference'] ?? '-',
    );
  }
}
