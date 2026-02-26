enum RoomStatusType { vacant, pending, booked, outOfService }

class RoomStatus {
  final String roomId;
  final RoomStatusType status;
  final DateTime? startDate; // optional
  final DateTime? endDate; // optional
  final List<DateTime>? dates; // optional
  final String? note;

  const RoomStatus({
    required this.roomId,
    required this.status,
    this.startDate,
    this.endDate,
    this.dates,
    this.note,
  });

  bool get isRange => startDate != null && endDate != null;
  bool get isSingle => startDate != null && endDate == null;
  bool get hasMultipleDates => dates != null && dates!.isNotEmpty;
}
