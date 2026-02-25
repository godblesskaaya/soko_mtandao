// domain/usecases/hotels/deactivate_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class DeactivateHotel implements UseCase<void, String> {
  final ManagerRepository repository;
  DeactivateHotel(this.repository);

  @override
  Future<Either<Failure, void>> call(String hotelId) async {
    try {
      await repository.deactivateHotel(hotelId);
      return Right(null);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'DeactivateHotel.call');
      return Left(ServerFailure("Failed to deactivate hotel"));
    }
  }
}
