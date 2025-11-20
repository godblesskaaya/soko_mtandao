// usecases/get_room_availability.dart
import '../entities/room.dart';
import '../repositories/hotel_repository.dart';

class GetRoomAvailability {
  final HotelRepository repository;

  GetRoomAvailability(this.repository);

  Future<List<Room>> call(String hotelId, String offeringId, DateTime start, DateTime end) {
    return repository.getRoomAvailability(hotelId, offeringId, start, end);
  }
}
