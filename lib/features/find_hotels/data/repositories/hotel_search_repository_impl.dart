import '../../domain/entities/hotel_entity.dart';
import '../../domain/entities/hotel_search_params.dart';
import '../../domain/repositories/hotel_search_repository.dart';
import '../datasources/hotel_search_remote_datasource.dart';

class HotelSearchRepositoryImpl implements HotelSearchRepository {
  final HotelSearchRemoteDataSource remote;

  HotelSearchRepositoryImpl(this.remote);

  @override
  Future<List<HotelEntity>> searchHotels(HotelSearchParams params) {
    return remote.searchHotels(params);
  }
}
