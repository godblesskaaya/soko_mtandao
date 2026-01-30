// lib/domain/entities/booking_cart.dart
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';

class BookingCart {
  final List<BookingInput> bookings;

  const BookingCart({this.bookings = const []});

  bool get isEmpty => bookings.isEmpty;

  int get totalItems =>
      bookings.fold(0, (sum, b) => sum + b.items.length);

  double get totalPrice =>
      bookings.fold(0, (sum, b) => sum + b.totalPrice);

  BookingCart addItem({
    required BookingInput booking,
    required BookingItemInput item,
  }) {
    final index = bookings.indexWhere((b) => b.bookingKey == booking.bookingKey);

    if (index == -1) {
      try {
        final newBooking = booking.addItem(item);
        return BookingCart(bookings: [...bookings, newBooking]);
      } on StateError catch (e) {
        // rethrow to indicate room already exists
        rethrow;
      }
    }

    final updatedBooking = bookings[index].addItem(item);
    final updatedBookings = [...bookings]..[index] = updatedBooking;

    return BookingCart(bookings: updatedBookings);
  }

  BookingCart removeItem({
    required String bookingId,
    required String roomId,
  }) {
    final updated = bookings
        .map((b) {
          if (b.id != bookingId) return b;
          final updatedBooking = b.removeItem(roomId);
          return updatedBooking.isEmpty ? null : updatedBooking;
        })
        .whereType<BookingInput>()
        .toList();

    return BookingCart(bookings: updated);
  }

  BookingCart clear() => const BookingCart();
}

