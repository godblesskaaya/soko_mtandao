import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'dart:convert';

class ManagerPaymentModel extends ManagerPayment {
  ManagerPaymentModel({
    required super.settlementId,
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
    required super.roomNumber
  });

  // data/models/manager_payment_model.dart
factory ManagerPaymentModel.fromJson(Map<String, dynamic> json) {
  debugPrint("managerpayment returned from supabase $json");
  return ManagerPaymentModel(
    settlementId: json['settlement_id'],
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
  );
}

}