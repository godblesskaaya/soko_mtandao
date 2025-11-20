// domain/usecases/offerings/get_offerings_for_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetOfferingsForHotel implements UseCase<List<ManagerOffering>, String> {
  final ManagerRepository repository;
  GetOfferingsForHotel(this.repository);

  @override
  Future<Either<Failure, List<ManagerOffering>>> call(String hotelId) async {
    try {
      List<ManagerOffering> offerings = await repository.getOfferings(hotelId);
      return Right(offerings);
    } catch (e, stackTrace) {
      print("Server error $e");
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch offerings: $e"));
    }
  }
}
