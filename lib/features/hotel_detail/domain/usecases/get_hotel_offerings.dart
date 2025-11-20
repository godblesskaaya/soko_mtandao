// usecases/get_hotel_offerings.dart
import '../entities/offering.dart';
import '../repositories/hotel_repository.dart';

class GetHotelOfferings {
  final HotelRepository repository;

  GetHotelOfferings(this.repository);

  Future<List<Offering>> call(String hotelId) {
    return repository.getHotelOfferings(hotelId);
  }
}
