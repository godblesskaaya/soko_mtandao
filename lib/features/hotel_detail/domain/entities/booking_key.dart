class BookingKey {
  final String hotelId;
  final DateTime startDate;
  final DateTime endDate;

  BookingKey({
    required this.hotelId,
    required DateTime startDate,
    required DateTime endDate,
  })  : startDate = _dateOnly(startDate),
        endDate = _dateOnly(endDate);

  @override
  bool operator ==(Object other) =>
      other is BookingKey &&
      other.hotelId == hotelId &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode =>
      Object.hash(hotelId, startDate, endDate);
}


DateTime _dateOnly(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day);
}
