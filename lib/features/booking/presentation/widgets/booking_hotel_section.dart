import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_room_item.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';

class BookingHotelSection extends StatelessWidget {
  final BookingInput booking;

  const BookingHotelSection({required this.booking});

  @override
  Widget build(BuildContext context) {
    final nights = booking.endDate.difference(booking.startDate).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.hotel.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        // display start and end date in yyyy-mm-dd format
        Text(
          '${booking.startDate.toIso8601String().substring(0, 10)} → ${booking.endDate.toIso8601String().substring(0, 10)}  ($nights nights)',
        ),
        const SizedBox(height: 8),
        ...booking.items.map((item) => BookingRoomItem(item: item, nights: nights)),
        const Divider(height: 32),
      ],
    );
  }
}
