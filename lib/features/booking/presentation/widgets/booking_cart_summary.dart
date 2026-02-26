import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';

class BookingCartSummary extends StatelessWidget {
  final BookingCart cart;

  const BookingCartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${cart.totalItems} item(s) in your booking cart'),
      trailing: Text(
        formatTzs(cart.totalPrice),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
