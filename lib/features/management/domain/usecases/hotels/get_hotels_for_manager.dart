// domain/usecases/hotels/get_hotels_for_manager.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetHotelsForManager
    implements UseCase<List<ManagerHotel>, HotelListParams> {
  final ManagerRepository repository;
  GetHotelsForManager(this.repository);

  @override
  Future<Either<Failure, List<ManagerHotel>>> call(
      HotelListParams params) async {
    try {
      List<ManagerHotel> hotels = await repository.getManagedHotels(
        params.managerUserId,
        filters: params.filters,
      );
      return Right(hotels);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetHotelsForManager.call');
      return Left(ServerFailure("Failed to fetch hotels"));
    }
  }
}

class HotelListParams {
  final String managerUserId;
  final Map<String, dynamic>? filters;

  const HotelListParams({
    required this.managerUserId,
    this.filters,
  });
}
