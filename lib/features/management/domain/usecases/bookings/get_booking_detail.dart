// domain/usecases/bookings/get_booking_detail.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetBookingDetail implements UseCase<ManagerBooking, String> {
  final ManagerRepository repository;
  GetBookingDetail(this.repository);

  @override
  Future<Either<Failure, ManagerBooking>> call(String bookingId) async {
    try {
      ManagerBooking booking = await repository.getBookingDetail(bookingId);
      return Right(booking);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetBookingDetail.call');
      return Left(ServerFailure("Failed to fetch booking details"));
    }
  }
}
