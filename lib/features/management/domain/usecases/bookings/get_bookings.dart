// domain/usecases/bookings/get_bookings.dart

import 'package:dartz/dartz.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/core/usecases/usecase.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/repositories/manager_repository.dart';

class GetBookingItems
    implements UseCase<List<ManagerBookingItem>, BookingQueryParams> {
  final ManagerRepository repository;
  GetBookingItems(this.repository);

  @override
  Future<Either<Failure, List<ManagerBookingItem>>> call(
      BookingQueryParams params) async {
    try {
      List<ManagerBookingItem> bookings = await repository.getBookingItems(
        hotelId: params.hotelId,
        filters: params.filters,
      );
      return Right(bookings);
    } catch (e, stackTrace) {
      ErrorReporter.report(e, stackTrace, source: 'GetBookingItems.call');
      return Left(ServerFailure("Failed to fetch bookings"));
    }
  }
}

class BookingQueryParams {
  final String hotelId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final String? status;

  const BookingQueryParams({
    required this.hotelId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'start_date',
    this.sortAscending = false,
    this.status,
  });

  int get offset => (page - 1) * limit;

  Map<String, dynamic> get filters => {
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_asc': sortAscending,
        if (status != null && status!.trim().isNotEmpty)
          'status': status!.trim(),
      };

  BookingQueryParams copyWith({
    int? page,
    int? limit,
    String? sortBy,
    bool? sortAscending,
    String? status,
  }) {
    return BookingQueryParams(
      hotelId: hotelId,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookingQueryParams &&
            runtimeType == other.runtimeType &&
            hotelId == other.hotelId &&
            page == other.page &&
            limit == other.limit &&
            sortBy == other.sortBy &&
            sortAscending == other.sortAscending &&
            status == other.status;
  }

  @override
  int get hashCode =>
      Object.hash(hotelId, page, limit, sortBy, sortAscending, status);
}
