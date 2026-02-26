import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room_details.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class ManagerRoomDetails {
  final ManagerRepository repository;

  ManagerRoomDetails(this.repository);

  ManagerRoom? room;
  ManagerOffering? offering;
  List<ManagerBookingItem> bookings = [];

  Future<Either<Failure, ManagerRoomDetailsData>> call(String roomId) async {
    try {
      room = await repository.getRoomById(roomId);
      if (room != null) {
        offering = await repository.getOfferingById(room!.offeringId);
        bookings = await repository.getBookingsForRoom(roomId: roomId);
      }
      return Right(ManagerRoomDetailsData(
          room: room!, offering: offering, bookings: bookings));
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'ManagerRoomDetails.call');
      return Left(ServerFailure("Failed to fetch room details"));
    }
  }
}
