import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';

class BookingCartSummary extends StatelessWidget {
  final BookingCart cart;

  const BookingCartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final roomNights = cart.bookings.fold<int>(
      0,
      (sum, booking) =>
          sum +
          booking.items.length *
              stayNightsInclusive(booking.startDate, booking.endDate),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text('${cart.totalItems} room(s) in your booking cart'),
        subtitle: Text('$roomNights room-night(s)'),
        trailing: Text(
          formatTzs(cart.totalPrice),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
