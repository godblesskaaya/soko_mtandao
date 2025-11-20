// domain/usecases/rooms/get_rooms_for_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetRoomById implements UseCase<ManagerRoom, String> {
  final ManagerRepository repository;
  GetRoomById(this.repository);

  @override
  Future<Either<Failure, ManagerRoom>> call(String roomId) async {
    try {
      ManagerRoom room = await repository.getRoomById(roomId);
      return Right(room);
    } catch (e, stackTrace) {
      print("serverFailure $e");
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch room: $e"));
    }
  }
}