class ManagerPayment {
  // Payment Details
  final String paymentId;
  final double amount;
  final String currency;
  final String paymentStatus;
  final String paymentType;
  final String? externalId;
  final String? paymentGatewayRef;
  final DateTime paymentCreatedAt;
  final DateTime paymentUpdatedAt;
  final Map<String, dynamic>? paymentMetadata;
  final Map<String, dynamic>? azampayResponse;
  final String? verifiedBy; // Assuming UUIDs are represented as Strings

  // Booking Details (Associated)
  final String bookingId;
  final String? hotelId;
  final String? ticketNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double? bookingTotalPrice;
  final String? bookingStatus;

  const ManagerPayment({
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.paymentType,
    this.externalId,
    this.paymentGatewayRef,
    required this.paymentCreatedAt,
    required this.paymentUpdatedAt,
    this.paymentMetadata,
    this.azampayResponse,
    this.verifiedBy,
    required this.bookingId,
    this.hotelId,
    this.ticketNumber,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.bookingTotalPrice,
    this.bookingStatus,
  });
}