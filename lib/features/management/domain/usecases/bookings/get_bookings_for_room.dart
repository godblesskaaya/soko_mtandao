// domain/usecases/bookings/get_bookings.dart

import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetBookingItemsForRoom
    implements UseCase<List<ManagerBookingItem>, String> {
  final ManagerRepository repository;
  GetBookingItemsForRoom(this.repository);

  @override
  Future<Either<Failure, List<ManagerBookingItem>>> call(String roomId) async {
    try {
      List<ManagerBookingItem> bookings =
          await repository.getBookingsForRoom(roomId: roomId);
      return Right(bookings);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace,
          source: 'GetBookingItemsForRoom.call');
      return Left(ServerFailure("Failed to fetch bookings for room"));
    }
  }
}
