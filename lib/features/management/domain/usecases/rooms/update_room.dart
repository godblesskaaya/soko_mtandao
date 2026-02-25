// domain/usecases/rooms/update_room.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class UpdateRoom implements UseCase<ManagerRoom, ManagerRoom> {
  final ManagerRepository repository;
  UpdateRoom(this.repository);

  @override
  Future<Either<Failure, ManagerRoom>> call(ManagerRoom room) async {
    try {
      ManagerRoom updatedRoom = await repository.updateRoom(room);
      return Right(updatedRoom);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'UpdateRoom.call');
      return Left(ServerFailure("Failed to update room"));
    }
  }
}
