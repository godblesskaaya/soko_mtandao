// domain/usecases/rooms/get_room_availability.dart

import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetRoomAvailability implements UseCase<RoomAvailability, AvailabilityParams> {
  final ManagerRepository repository;
  GetRoomAvailability(this.repository);

  @override
  Future<Either<Failure, RoomAvailability>> call(AvailabilityParams params) async {
    try {
      RoomAvailability availability = await repository.getRoomAvailability(params.roomId, params.startDate, params.endDate);
      return Right(availability);
    } catch (e) {
      return Left(ServerFailure("Failed to fetch room availability: $e"));
    }
  }
}

class AvailabilityParams {
  final String roomId;
  final DateTime startDate;
  final DateTime endDate;

  AvailabilityParams({required this.roomId, required this.startDate, required this.endDate});
}
