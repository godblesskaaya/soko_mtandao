// domain/usecases/hotels/get_hotel_detail.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetHotelDetail implements UseCase<ManagerHotel, String> {
  final ManagerRepository repository;
  GetHotelDetail(this.repository);

  @override
  Future<Either<Failure, ManagerHotel>> call(String hotelId) async {
    try {
      ManagerHotel hotel = await repository.getHotelDetail(hotelId);
      return Right(hotel);
    } catch (e) {
      return Left(ServerFailure("Failed to fetch hotel details: $e"));
    }
  }
}
