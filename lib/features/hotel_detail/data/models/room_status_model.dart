import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';

class RoomStatusModel extends RoomStatus{
  RoomStatusModel({
    required super.startDate,
    required super.status,
    required super.roomId,
  });

  factory RoomStatusModel.fromJson(Map<String, dynamic> json) {
    return RoomStatusModel(
      startDate: DateTime.parse(json['start_date']),
      status: RoomStatusType.values.firstWhere((e) => e.toString() == 'RoomStatusType.${json['status']}'),
      roomId: json['room_id'],
    );
  }
}