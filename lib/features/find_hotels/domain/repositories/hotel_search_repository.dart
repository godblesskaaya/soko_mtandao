import '../entities/hotel_entity.dart';
import '../entities/hotel_search_params.dart';

abstract class HotelSearchRepository {
  Future<List<HotelEntity>> searchHotels(HotelSearchParams params);
}
