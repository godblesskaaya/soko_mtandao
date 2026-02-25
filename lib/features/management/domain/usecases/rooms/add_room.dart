// domain/usecases/rooms/add_room.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class AddRoom implements UseCase<ManagerRoom, ManagerRoom> {
  final ManagerRepository repository;
  AddRoom(this.repository);

  @override
  Future<Either<Failure, ManagerRoom>> call(ManagerRoom room) async {
    try {
      ManagerRoom createdRoom = await repository.createRoom(room);
      return Right(createdRoom);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'AddRoom.call');
      return Left(ServerFailure("Failed to add room"));
    }
  }
}
