// repositories/hotel_repository.dart
import '../entities/hotel.dart';
import '../entities/offering.dart';
import '../entities/room.dart';

abstract class HotelRepository {
  Future<Hotel> getHotelDetail(String hotelId);
  Future<List<Offering>> getHotelOfferings(String hotelId);
  Future<List<Room>> getRoomAvailability(
      String hotelId, String offeringId, DateTime start, DateTime end);
}
