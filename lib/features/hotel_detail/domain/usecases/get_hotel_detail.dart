// usecases/get_hotel_detail.dart
import '../entities/hotel.dart';
import '../repositories/hotel_repository.dart';

class GetHotelDetail {
  final HotelRepository repository;

  GetHotelDetail(this.repository);

  Future<Hotel> call(String hotelId) {
    return repository.getHotelDetail(hotelId);
  }
}
