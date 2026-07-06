class ManagerPayment {
  final String settlementId;
  final String hotelId;
  final String bookingId;
  final double amount;
  final String status;
  final DateTime date;

  // Room/Stay Info
  final String roomNumber;
  final int nights;
  final double rate;
  final DateTime checkIn;
  final DateTime checkOut;

  // Customer Info
  final String customerName;
  final String customerPhone;
  final String ticketNumber;

  // Audit Info
  final String gatewayRef;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentProviderStatus;
  final String paymentReconciliationStatus;
  final String bookingStatus;
  final String bookingPaymentStatus;
  final String bookingReconciliationStatus;
  final double grossAmount;
  final double commissionAmount;
  final double taxAmount;
  final double hotelNetAmount;
  final double providerFeeAmount;
  final String payoutStatus;
  final String payoutProviderStatus;
  final String payoutProviderReference;
  final String payoutExternalReference;

  ManagerPayment({
    required this.settlementId,
    required this.hotelId,
    required this.bookingId,
    required this.amount,
    required this.status,
    required this.date,
    required this.roomNumber,
    required this.nights,
    required this.rate,
    required this.checkIn,
    required this.checkOut,
    required this.customerName,
    required this.customerPhone,
    required this.ticketNumber,
    required this.gatewayRef,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentProviderStatus,
    required this.paymentReconciliationStatus,
    required this.bookingStatus,
    required this.bookingPaymentStatus,
    required this.bookingReconciliationStatus,
    required this.grossAmount,
    required this.commissionAmount,
    required this.taxAmount,
    required this.hotelNetAmount,
    required this.providerFeeAmount,
    required this.payoutStatus,
    required this.payoutProviderStatus,
    required this.payoutProviderReference,
    required this.payoutExternalReference,
  });
}
