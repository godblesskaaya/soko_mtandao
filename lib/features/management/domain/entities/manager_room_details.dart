// domain/entities/manager_room_details.dart
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';

class ManagerRoomDetailsData {
  final ManagerRoom room;
  final ManagerOffering? offering;
  final List<ManagerBookingItem> bookings;

  ManagerRoomDetailsData({
    required this.room,
    this.offering,
    this.bookings = const [],
  });
}
