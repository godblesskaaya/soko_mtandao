// domain/usecases/offerings/delete_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class DeleteRoom implements UseCase<void, String> {
  final ManagerRepository repository;
  DeleteRoom(this.repository);

  @override
  Future<Either<Failure, void>> call(String roomId) async {
    try {
      await repository.deleteRoom(roomId);
      return Right(null);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'DeleteRoom.call');
      return Left(ServerFailure("Failed to delete room"));
    }
  }
}
