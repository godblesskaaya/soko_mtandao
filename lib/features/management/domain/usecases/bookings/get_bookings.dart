// domain/usecases/bookings/get_bookings.dart

import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetBookingItems implements UseCase<List<ManagerBookingItem>, BookingQueryParams> {
  final ManagerRepository repository;
  GetBookingItems(this.repository);

  @override
  Future<Either<Failure, List<ManagerBookingItem>>> call(BookingQueryParams params) async {
    try {
      List<ManagerBookingItem> bookings = await repository.getBookingItems(
        hotelId: params.hotelId,
        filters: params.filters,
      );
      return Right(bookings);
    } catch (e, stackTrace) {
      print('error fetching bookings $e');
      print(stackTrace);
      return Left(ServerFailure("Failed to fetch bookings: $e"));
    }
  }
}

class BookingQueryParams {
  final String hotelId;
  final Map<String, dynamic> filters;

  BookingQueryParams({
    required this.hotelId,
    required this.filters,
  });
}
