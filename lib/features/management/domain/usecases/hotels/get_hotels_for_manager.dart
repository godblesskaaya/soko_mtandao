// domain/usecases/hotels/get_hotels_for_manager.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetHotelsForManager implements UseCase<List<ManagerHotel>, String> {
  final ManagerRepository repository;
  GetHotelsForManager(this.repository);

  @override
  Future<Either<Failure, List<ManagerHotel>>> call(String managerUserId) async {
    try {
      List<ManagerHotel> hotels = await repository.getManagedHotels(managerUserId);
      print(hotels);
      return Right(hotels);
    } catch (e, stackTrace) {
      print('Server error: $e');
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch hotels: $e"));
    }
  }
}
