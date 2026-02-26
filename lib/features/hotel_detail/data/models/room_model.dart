import 'package:soko_mtandao/features/hotel_detail/domain/entities/room.dart';

class RoomModel extends Room {
  RoomModel({
    required super.id,
    required super.number,
    required super.status,
    required super.offeringId,
  });

  factory RoomModel.fromEntity(Room room) {
    return RoomModel(
      id: room.id,
      number: room.number,
      status: room.status,
      offeringId: room.offeringId,
    );
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'],
      number: json['room_number'] ?? '',
      status: getRoomStatusFromString(json['status']) ?? RoomStatus.pending,
      offeringId: json['offering_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_number': number,
      'status': status?.name,
      'offering_id': offeringId,
    };
  }

  static getRoomStatusFromString(json) {
    switch (json) {
      case 'available':
        return RoomStatus.vacant;
      case 'booked':
        return RoomStatus.booked;
      case 'pending':
        return RoomStatus.pending;
      default:
        return null;
    }
  }
}
