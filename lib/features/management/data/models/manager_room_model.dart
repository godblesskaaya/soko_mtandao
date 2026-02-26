import 'package:soko_mtandao/features/hotel_detail/data/models/room_availability_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';

class ManagerRoomModel extends ManagerRoom {
  ManagerRoomModel({
    required String id,
    required String hotelId,
    required String offeringId,
    required String roomNumber,
    required int capacity,
    required bool isActive,
  }) : super(
          id: id,
          hotelId: hotelId,
          offeringId: offeringId,
          roomNumber: roomNumber,
          capacity: capacity,
          isActive: isActive,
        );

  factory ManagerRoomModel.fromJson(Map<String, dynamic> json) {
    return ManagerRoomModel(
      id: json['id'],
      hotelId: json['hotel_id'],
      offeringId: json['offering_id'],
      roomNumber: json['room_number'],
      capacity: json['capacity'] ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }

  factory ManagerRoomModel.fromEntity(ManagerRoom room) {
    return ManagerRoomModel(
      id: room.id,
      hotelId: room.hotelId,
      offeringId: room.offeringId,
      roomNumber: room.roomNumber,
      capacity: room.capacity,
      isActive: room.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // if (id != null || id.isNotEmpty) 'id': id,
      'hotel_id': hotelId,
      'offering_id': offeringId,
      'room_number': roomNumber,
      'capacity': capacity,
      'is_active': isActive,
    };
  }
}
