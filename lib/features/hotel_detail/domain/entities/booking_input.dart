import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_key.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/hotel.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';
import 'package:uuid/uuid.dart';

class BookingInput {
  final String id;
  final Hotel hotel;
  final DateTime startDate;
  final DateTime endDate;
  final List<BookingItemInput> items;

  late final BookingKey bookingKey = BookingKey(
    hotelId: hotel.id,
    startDate: startDate,
    endDate: endDate,
  );

  BookingInput({
    String? id,
    required this.hotel,
    required this.startDate,
    required this.endDate,
    required this.items,
  }) : id = id ?? const Uuid().v4() {
    _validateDates();
  }
  
  // Validate that endDate is after startDate and cant be the same
  void _validateDates() {
    if (!endDate.isAfter(startDate)) {
      throw ArgumentError('endDate must be after startDate');
    }
  }

  
  BookingInput addItem(BookingItemInput item) {
    if (items.any((i) => i.room.id == item.room.id)) {
      throw StateError('Room already added to booking');
    }

    return copyWith(items: [...items, item]);
  }

  BookingInput removeItem(String roomId) {
    final updated = items.where((i) => i.room.id != roomId).toList();
    return copyWith(items: updated);
  }

  BookingInput copyWith({
    Hotel? hotel,
    DateTime? startDate,
    DateTime? endDate,
    List<BookingItemInput>? items,
  }) {
    return BookingInput(
      id: id,
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
