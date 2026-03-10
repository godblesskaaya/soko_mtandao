import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';
import 'package:soko_mtandao/features/booking/presentation/widgets/booking_room_item.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';

class BookingHotelSection extends StatelessWidget {
  final BookingInput booking;

  const BookingHotelSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final nights = stayNightsInclusive(booking.startDate, booking.endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.hotel.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          '${formatYmd(booking.startDate)} -> ${formatYmd(booking.endDate)}  ($nights nights)',
        ),
        const SizedBox(height: 8),
        ...booking.items
            .map((item) => BookingRoomItem(item: item, nights: nights)),
        const Divider(height: 32),
      ],
    );
  }
}
