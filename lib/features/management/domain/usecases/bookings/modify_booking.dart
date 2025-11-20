// domain/usecases/bookings/modify_booking.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class ModifyBooking implements UseCase<ManagerBooking, ManagerBooking> {
  final ManagerRepository repository;
  ModifyBooking(this.repository);

  @override
  Future<Either<Failure, ManagerBooking>> call(ManagerBooking booking) async {
    try {
      ManagerBooking updatedBooking = await repository.updateBooking(booking);
      return Right(updatedBooking);
    } catch (e) {
      return Left(ServerFailure("Failed to modify booking: $e"));
    }
  }
}
