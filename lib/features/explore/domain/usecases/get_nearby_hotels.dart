import '../entities/hotel.dart';
import '../repositories/hotel_repository.dart';

class GetNearbyHotels {
  final HotelRepository repository;
  GetNearbyHotels(this.repository);

  Future<List<Hotel>> call({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) {
    return repository.getNearbyHotels(lat: lat, lng: lng, radiusKm: radiusKm);
  }
}
