// domain/usecases/offerings/get_offerings_for_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetOfferingsById implements UseCase<ManagerOffering, String> {
  final ManagerRepository repository;
  GetOfferingsById(this.repository);

  @override
  Future<Either<Failure, ManagerOffering>> call(String offeringId) async {
    try {
      ManagerOffering offering = await repository.getOfferingById(offeringId);
      return Right(offering);
    } catch (e, stackTrace) {
      print("Server error $e");
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch offering: $e"));
    }
  }
}
