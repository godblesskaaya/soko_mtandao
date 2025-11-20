// domain/usecases/rooms/update_room_status.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class UpdateRoomStatus implements UseCase<void, RoomStatus> {
  final ManagerRepository repository;
  UpdateRoomStatus(this.repository);

  @override
  Future<Either<Failure, void>> call(RoomStatus newStatus) async {
    try {
      await repository.updateRoomStatus(newStatus);
      return Right(null);
    } catch (e) {
      return Left(ServerFailure("Failed to update room status: $e"));
    }
  }
}
