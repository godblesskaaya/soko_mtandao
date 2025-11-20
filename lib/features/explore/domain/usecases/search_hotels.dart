import '../entities/hotel.dart';
import '../repositories/hotel_repository.dart';

class SearchHotels {
  final HotelRepository repository;
  SearchHotels(this.repository);

  Future<List<Hotel>> call({
    required String query,
    required double lat,
    required double lng,
  }) {
    return repository.searchHotels(query: query, lat: lat, lng: lng);
  }
}
