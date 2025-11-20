// domain/usecases/rooms/get_rooms_for_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetRoomsForOffering implements UseCase<List<ManagerRoom>, String> {
  final ManagerRepository repository;
  GetRoomsForOffering(this.repository);

  @override
  Future<Either<Failure, List<ManagerRoom>>> call(String offeringId) async {
    try {
      List<ManagerRoom> rooms = await repository.getRoomsByOffering(offeringId);
      return Right(rooms);
    } catch (e) {
      return Left(ServerFailure("Failed to fetch rooms for offering: $e"));
    }
  }
}
