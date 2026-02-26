class ManagerBookingItem {
  final String id;
  final String? bookingId;
  final String? roomId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? hotelId;
  final String? offeringId;
  final DateTime? createdAt;

  ManagerBookingItem({
    required this.id,
    this.bookingId,
    this.roomId,
    this.startDate,
    this.endDate,
    this.hotelId,
    this.offeringId,
    this.createdAt,
  });
}
