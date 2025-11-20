// domain/usecases/hotels/update_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class UpdateHotel implements UseCase<ManagerHotel, ManagerHotel> {
  final ManagerRepository repository;
  UpdateHotel(this.repository);

  @override
  Future<Either<Failure, ManagerHotel>> call(ManagerHotel hotel) async {
    try {
      ManagerHotel updatedHotel = await repository.updateHotel(hotel);
      return Right(updatedHotel);
    } catch (e) {
      return Left(ServerFailure("Failed to update hotel: $e"));
    }
  }
}
