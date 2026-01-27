// models/booking_cart_model.dart
import 'package:soko_mtandao/features/hotel_detail/data/models/booking_input_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';

class BookingCartModel extends BookingCart {
  BookingCartModel({
    required List<BookingInput> bookings,
  }) : super(bookings: bookings);

  factory BookingCartModel.fromEntity(BookingCart cart) {
    return BookingCartModel(
      bookings: cart.bookings,
    );
  }

  // Factory constructor to create a BookingCartModel from JSON
  factory BookingCartModel.fromJson(dynamic json) {
    if (json is List) {
      return BookingCartModel(
        bookings: json
            .map((e) => BookingInputModel.fromJson(e))
            .toList(),
      );
    } else if (json is Map<String, dynamic>) {
      return BookingCartModel(
        bookings: (json['bookings'] as List<dynamic>)
            .map((e) => BookingInputModel.fromJson(e))
            .toList(),
      );
    } else {
      print('Invalid JSON type for BookingCartModel: ${json.runtimeType}');
      print('JSON content: $json');
      throw ArgumentError('Invalid JSON type for BookingCartModel');
    }
  }

  // Method to serialize BookingCartModel into JSON
  Map<String, dynamic> toJson() {
    return {
      'bookings': bookings.map((booking) => BookingInputModel.fromEntity(booking).toJson()).toList(),
    };
  }
}
