import 'package:soko_mtandao/features/hotel_detail/domain/entities/hotel.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';

class BookingInput {
  final Hotel hotel;
  final DateTime startDate;
  final DateTime endDate;
  final List<BookingItemInput> items;

  BookingInput({
    required this.hotel,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  BookingInput copyWith({
    Hotel? hotel,
    DateTime? startDate,
    DateTime? endDate,
    List<BookingItemInput>? items,
  }) {
    return BookingInput(
      hotel: hotel ?? this.hotel,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      items: items ?? this.items,
    );
  }

  bool get isEmpty => items.isEmpty;
  int get totalItems => items.length;

  double get totalPrice {
    final nights = endDate.difference(startDate).inDays;
    return items.fold(0, (sum, item) => sum + (item.offering.pricePerNight * nights));
  }
}
