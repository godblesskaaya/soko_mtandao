class ManagerPayment {
  final String settlementId;
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

  ManagerPayment({
    required this.settlementId,
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
  });
}