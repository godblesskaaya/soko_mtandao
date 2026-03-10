import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/utils/currency.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';

class BookingRoomItem extends StatelessWidget {
  final BookingItemInput item;
  final int nights;

  const BookingRoomItem({required this.item, required this.nights});

  @override
  Widget build(BuildContext context) {
    final roomLabel = item.room.number ?? item.room.id;
    final title = item.offering.title ?? 'Room Offering ${item.offering.id}';
    final price = item.offering.pricePerNight;

    return ListTile(
      leading: const Icon(Icons.meeting_room),
      title: Text(title),
      subtitle:
          Text('Room $roomLabel  |  ${formatTzs(price)} x $nights night(s)'),
      trailing: Text(formatTzs(price * nights)),
    );
  }
}
