// entities/room.dart
enum RoomStatus { vacant, pending, booked }

class Room {
  final String id;
  final String number;
  RoomStatus? status;
  final String offeringId;

  Room({
    required this.id,
    required this.number,
    this.status,
    required this.offeringId,
  });
}
