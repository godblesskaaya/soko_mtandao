import '../entities/hotel.dart';
import '../repositories/hotel_repository.dart';

class GetHotelsInBounds {
  final HotelRepository repository;
  GetHotelsInBounds(this.repository);

  Future<List<Hotel>> call({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    return repository.getHotelsInBounds(
        south: south, west: west, north: north, east: east);
  }
}
