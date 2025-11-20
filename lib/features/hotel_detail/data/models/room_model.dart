import 'package:soko_mtandao/features/hotel_detail/domain/entities/room.dart';

class RoomModel extends Room{
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
      status: json['status'] ?? RoomStatus.pending,
      offeringId: json['offering_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'status': status,
      'offeringId': offeringId,
    };
  }
}