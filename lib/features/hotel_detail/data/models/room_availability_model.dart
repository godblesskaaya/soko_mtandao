import 'package:soko_mtandao/features/hotel_detail/data/models/room_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';

class RoomAvailabilityModel extends RoomAvailability {
  RoomAvailabilityModel({
    required super.room,
    required super.availabilityByDate,
  });

  factory RoomAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return RoomAvailabilityModel(
      room: RoomModel.fromJson(json['room']),
      availabilityByDate:
          (json['availabilityByDate'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
            DateTime.parse(key),
            RoomStatusType.values
                .firstWhere((e) => e.toString() == 'RoomStatusType.$value')),
      ),
    );
  }

  factory RoomAvailabilityModel.fromEntity(RoomAvailability availability) {
    return RoomAvailabilityModel(
      room: RoomModel.fromEntity(availability.room),
      availabilityByDate: availability.availabilityByDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'room': (room as RoomModel).toJson(),
        'availabilityByDate': availabilityByDate.map((key, value) =>
            MapEntry(key.toIso8601String(), value.toString().split('.').last)),
      };
}
