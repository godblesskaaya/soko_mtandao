import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetAmenities implements UseCase<List<ManagerAmenity>, NoParams> {
  final ManagerRepository repository;
  GetAmenities(this.repository);

  @override
  Future<Either<Failure, List<ManagerAmenity>>> call(NoParams params) async {
    try {
      List<ManagerAmenity> amenities = await repository.getAmenities();
      return Right(amenities);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetAmenities.call');
      return Left(ServerFailure("Failed to fetch amenities"));
    }
  }
}
