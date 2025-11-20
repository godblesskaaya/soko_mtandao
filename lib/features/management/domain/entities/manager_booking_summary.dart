class ManagerBookingSummary {
  final String id;
  final String hotelId;
  final String offeringTitle;
  final String roomNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String guestName;
  final String status;
  final double totalPrice;

  ManagerBookingSummary({
    required this.id,
    required this.hotelId,
    required this.offeringTitle,
    required this.roomNumber,
    required this.startDate,
    required this.endDate,
    required this.guestName,
    required this.status,
    required this.totalPrice,
  });
}
