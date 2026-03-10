// models/booking_input_model.dart
import 'package:soko_mtandao/features/hotel_detail/data/models/hotel_model.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_item_input_model.dart';

class BookingInputModel extends BookingInput {
  BookingInputModel({
    required super.hotel,
    required super.startDate,
    required super.endDate,
    required super.items,
  });

  factory BookingInputModel.fromEntity(BookingInput booking) {
    return BookingInputModel(
      hotel: booking.hotel,
      startDate: booking.startDate,
      endDate: booking.endDate,
      items: booking.items,
    );
  }

  // Factory constructor to create a BookingInputModel from JSON
  factory BookingInputModel.fromJson(Map<String, dynamic> json) {
    return BookingInputModel(
      hotel: HotelModel.fromJson(json['hotel']),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      items: (json['items'] as List<dynamic>)
          .map((itemJson) => BookingItemInputModel.fromJson(itemJson))
          .toList(),
    );
  }

  // Method to serialize BookingInputModel into JSON
  Map<String, dynamic> toJson() {
    return {
      'hotel': HotelModel.fromEntity(hotel).toJson(),
      'start_date': formatYmd(startDate),
      'end_date': formatYmd(endDate),
      'items': items
          .map((item) => BookingItemInputModel.fromEntity(item).toJson())
          .toList(),
    };
  }
}
