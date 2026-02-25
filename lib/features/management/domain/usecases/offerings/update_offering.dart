// domain/usecases/offerings/update_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class UpdateOffering implements UseCase<ManagerOffering, ManagerOffering> {
  final ManagerRepository repository;
  UpdateOffering(this.repository);

  @override
  Future<Either<Failure, ManagerOffering>> call(ManagerOffering offering) async {
    try {
      ManagerOffering updatedOffering = await repository.updateOffering(offering);
      return Right(updatedOffering);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'UpdateOffering.call');
      return Left(ServerFailure("Failed to update offering"));
    }
  }
}
