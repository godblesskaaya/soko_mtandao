// domain/usecases/offerings/get_offerings_for_hotel.dart
import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetOfferingsForHotel implements UseCase<List<ManagerOffering>, OfferingListParams> {
  final ManagerRepository repository;
  GetOfferingsForHotel(this.repository);

  @override
  Future<Either<Failure, List<ManagerOffering>>> call(OfferingListParams params) async {
    try {
      List<ManagerOffering> offerings = await repository.getOfferings(
        params.hotelId,
        filters: params.filters,
      );
      return Right(offerings);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetOfferingsForHotel.call');
      return Left(ServerFailure("Failed to fetch offerings"));
    }
  }
}

class OfferingListParams {
  final String hotelId;
  final Map<String, dynamic>? filters;

  const OfferingListParams({
    required this.hotelId,
    this.filters,
  });
}
