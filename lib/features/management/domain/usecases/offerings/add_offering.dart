// domain/usecases/offerings/add_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class AddOffering implements UseCase<ManagerOffering, ManagerOffering> {
  final ManagerRepository repository;
  AddOffering(this.repository);

  @override
  Future<Either<Failure, ManagerOffering>> call(
      ManagerOffering offering) async {
    try {
      ManagerOffering createdOffering =
          await repository.createOffering(offering);
      return Right(createdOffering);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'AddOffering.call');
      return Left(ServerFailure("Failed to add offering"));
    }
  }
}
