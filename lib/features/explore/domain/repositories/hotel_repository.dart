import '../entities/hotel.dart';

abstract class HotelRepository {
  Future<List<Hotel>> getNearbyHotels({
    required double lat,
    required double lng,
    double radiusKm,
  });

  Future<List<Hotel>> getHotelsInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  });

  Future<List<Hotel>> searchHotels({
    required String query,
    required double lat,
    required double lng,
  });

  Future<Hotel> getHotelById(String id);
}
