import 'package:soko_mtandao/features/hotel_detail/domain/entities/room.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';

class RoomAvailability {
  final Room room;
  final Map<DateTime, RoomStatusType> availabilityByDate;

  RoomAvailability({
    required this.room,
    required this.availabilityByDate,
  });
}
