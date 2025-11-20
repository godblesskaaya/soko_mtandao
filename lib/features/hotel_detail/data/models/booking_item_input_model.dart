// models/booking_item_input_model.dart
import 'package:soko_mtandao/features/hotel_detail/data/models/offering_model.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/room_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';

class BookingItemInputModel extends BookingItemInput {
  BookingItemInputModel({
    required super.offering,
    required super.room,
  });

  factory BookingItemInputModel.fromEntity(BookingItemInput item) {
    return BookingItemInputModel(
      offering: item.offering,
      room: item.room,
    );
  }

  // Factory constructor to create a BookingItemInputModel from JSON
  factory BookingItemInputModel.fromJson(Map<String, dynamic> json) {
    return BookingItemInputModel(
      offering: OfferingModel.fromJson(json['offering']),
      room: RoomModel.fromJson(json['room']),
    );
  }

  // Method to serialize BookingItemInputModel into JSON
  Map<String, dynamic> toJson() {
    return {
      'offering': OfferingModel.fromEntity(offering).toJson(),
      'room': RoomModel.fromEntity(room).toJson(),
    };
  }
}
