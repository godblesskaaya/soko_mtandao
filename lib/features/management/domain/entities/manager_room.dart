import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';

class ManagerRoom {
  final String id;
  final String hotelId;
  final String offeringId;
  final String roomNumber;
  final int capacity;
  final bool isActive;

  ManagerRoom({
    required this.id,
    required this.hotelId,
    required this.offeringId,
    required this.roomNumber,
    required this.capacity,
    this.isActive = true,
  });
}
