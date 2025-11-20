// lib/domain/entities/booking_cart.dart
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';

class BookingCart {
  final List<BookingInput> bookings;
  
  BookingCart({
    required this.bookings,
  });

  BookingCart copyWith({List<BookingInput>? bookings}) {
    return BookingCart(
      bookings: bookings ?? this.bookings,
    );
  }

  bool get isEmpty => bookings.isEmpty;
  int get totalItems => bookings.fold(0, (sum, booking) => sum + booking.totalItems);

// calculate total price based on bookings in cart
  double get totalPrice {
    return bookings.fold(0, (sum, booking) => sum + booking.totalPrice);
  }
}
