import 'package:soko_mtandao/features/hotel_detail/domain/entities/offering.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room.dart';

class BookingItemInput {
  final Offering offering;
  final Room room;

  BookingItemInput({
    required this.offering,
    required this.room,
  });
}