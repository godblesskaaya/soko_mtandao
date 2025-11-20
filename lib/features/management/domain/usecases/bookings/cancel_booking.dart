// domain/usecases/bookings/cancel_booking.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class CancelBooking implements UseCase<void, String> {
  final ManagerRepository repository;
  CancelBooking(this.repository);

  @override
  Future<Either<Failure, void>> call(String bookingId) {
    return repository.cancelBooking(bookingId).then((_) => Right(null));
  }
}
