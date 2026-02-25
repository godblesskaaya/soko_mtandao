// domain/usecases/offerings/delete_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class DeleteOffering implements UseCase<void, String> {
  final ManagerRepository repository;
  DeleteOffering(this.repository);

  @override
  Future<Either<Failure, void>> call(String offeringId) async {
    try {
      await repository.deleteOffering(offeringId);
      return Right(null);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'DeleteOffering.call');
      return Left(ServerFailure("Failed to delete offering"));
    }
  }
}
