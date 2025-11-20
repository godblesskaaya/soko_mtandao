// domain/usecases/rooms/get_rooms_for_offering.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetRooms implements UseCase<List<ManagerRoom>, RoomParams> {
  final ManagerRepository repository;
  GetRooms(this.repository);

  @override
  Future<Either<Failure, List<ManagerRoom>>> call(RoomParams params) async {
    try {
      List<ManagerRoom> rooms = await repository.getRooms(params.hotelId!, params.filters);
      return Right(rooms);
    } catch (e, stackTrace) {
      print("serverFailure $e");
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch rooms: $e"));
    }
  }
}

class RoomParams {
  final String? hotelId;
  final Map<String, dynamic>? filters;

  RoomParams({this.hotelId, this.filters});
}
