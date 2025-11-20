class BookingConflict {
  final String roomId;
  final String? roomNumber;
  final DateTime date;

  BookingConflict({
    required this.roomId,
    this.roomNumber,
    required this.date,
  });

  factory BookingConflict.fromJson(Map<String, dynamic> json) {
    return BookingConflict(
      roomId: json['room_id'] as String,
      roomNumber: json['room_number'] as String?,
      date: DateTime.parse(json['date']),
    );
  }
}

class BookingConflictException implements Exception {
  final String message;
  final List<BookingConflict> conflicts;

  BookingConflictException({
    required this.message,
    required this.conflicts,
  });

  @override
  String toString() => 'BookingConflictException: $message (${conflicts.length} conflicts)';
}
