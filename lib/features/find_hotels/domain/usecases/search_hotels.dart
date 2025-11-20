import '../entities/hotel_entity.dart';
import '../entities/hotel_search_params.dart';
import '../repositories/hotel_search_repository.dart';

class SearchHotels {
  final HotelSearchRepository repository;

  SearchHotels(this.repository);

  Future<List<HotelEntity>> call(HotelSearchParams params) {
    return repository.searchHotels(params);
  }
}
