import '../entities/hotel.dart';
import '../repositories/hotel_repository.dart';

class GetHotelById {
  final HotelRepository repository;
  GetHotelById(this.repository);

  Future<Hotel> call(String id) => repository.getHotelById(id);
}
