import '../../domain/entities/hotel.dart';
import '../../domain/repositories/hotel_repository.dart';
import '../datasources/hotel_datasource.dart';

class HotelRepositoryImpl implements HotelRepository {
  final HotelDataSource dataSource;
  HotelRepositoryImpl(this.dataSource);

  @override
  Future<List<Hotel>> getNearbyHotels(
      {required double lat, required double lng, double radiusKm = 5}) {
    return dataSource.fetchNearbyHotels(lat: lat, lng: lng, radiusKm: radiusKm);
  }

  @override
  Future<List<Hotel>> getHotelsInBounds(
      {required double south,
      required double west,
      required double north,
      required double east}) {
    return dataSource.fetchHotelsInBounds(
        south: south, west: west, north: north, east: east);
  }

  @override
  Future<List<Hotel>> searchHotels(
      {required String query, required double lat, required double lng}) {
    return dataSource.searchHotels(query: query, lat: lat, lng: lng);
  }

  @override
  Future<Hotel> getHotelById(String id) => dataSource.fetchHotelById(id);
}
