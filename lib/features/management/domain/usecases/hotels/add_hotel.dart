// domain/usecases/hotels/add_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/explore/domain/entities/hotel.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class AddHotel implements UseCase<ManagerHotel, ManagerHotel> {
  final ManagerRepository repository;
  AddHotel(this.repository);

  @override
  Future<Either<Failure, ManagerHotel>> call(ManagerHotel hotel) async{
    try {
      ManagerHotel createdHotel = await repository.createHotel(hotel);
      return Right(createdHotel);
    } catch (e) {
      return Left(ServerFailure("Failed to add hotel: $e"));
    }
  }
}
