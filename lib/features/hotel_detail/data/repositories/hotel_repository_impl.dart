// repositories/hotel_repository_impl.dart
import 'package:soko_mtandao/features/hotel_detail/data/datasources/hotel_remote_datasource.dart';

import '../../domain/entities/hotel.dart';
import '../../domain/entities/offering.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/hotel_repository.dart';
import '../datasources/hotel_mock_datasource.dart';

class HotelRepositoryImpl implements HotelRepository {
  final HotelDetailDataSource dataSource;

  HotelRepositoryImpl(this.dataSource);

  @override
  Future<Hotel> getHotelDetail(String hotelId) {
    return dataSource.fetchHotelDetail(hotelId);
  }

  @override
  Future<List<Offering>> getHotelOfferings(String hotelId) {
    return dataSource.fetchHotelOfferings(hotelId);
  }

  @override
  Future<List<Room>> getRoomAvailability(
      String hotelId, String offeringId, DateTime start, DateTime end) {
    return dataSource.fetchRoomAvailability(hotelId, offeringId, start, end);
  }
}
