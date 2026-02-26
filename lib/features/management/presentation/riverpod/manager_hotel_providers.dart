// presentation/riverpod/hotels/hotel_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/add_hotel.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_hotels_for_manager.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_hotel_detail.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerHotelListQuery {
  final String managerUserId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final bool? isActive;

  const ManagerHotelListQuery({
    required this.managerUserId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'name',
    this.sortAscending = true,
    this.isActive,
  });

  int get offset => (page - 1) * limit;

  Map<String, dynamic> get filters => {
        'limit': limit,
        'offset': offset,
        'sort_by': sortBy,
        'sort_asc': sortAscending,
        if (isActive != null) 'is_active': isActive,
      };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ManagerHotelListQuery &&
            runtimeType == other.runtimeType &&
            managerUserId == other.managerUserId &&
            page == other.page &&
            limit == other.limit &&
            sortBy == other.sortBy &&
            sortAscending == other.sortAscending &&
            isActive == other.isActive;
  }

  @override
  int get hashCode =>
      Object.hash(managerUserId, page, limit, sortBy, sortAscending, isActive);
}

// DI providers for use cases
final getHotelsForManagerProvider = Provider<GetHotelsForManager>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetHotelsForManager(repo);
});

final getHotelDetailProvider = Provider<GetHotelDetail>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetHotelDetail(repo);
});

final addHotelUseCaseProvider = Provider<AddHotel>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return AddHotel(repo);
});

// FutureProviders for data fetching
final managerHotelsPageProvider =
    FutureProvider.family<List<ManagerHotel>, ManagerHotelListQuery>(
        (ref, query) {
  return ref
      .watch(getHotelsForManagerProvider)
      .call(HotelListParams(
          managerUserId: query.managerUserId, filters: query.filters))
      .then((result) =>
          result.fold((failure) => throw failure, (hotels) => hotels));
});

final managerHotelsProvider =
    FutureProvider.family<List<ManagerHotel>, String>((ref, managerUserId) {
  return ref.watch(
    managerHotelsPageProvider(
            ManagerHotelListQuery(managerUserId: managerUserId))
        .future,
  );
});

final hotelDetailProvider =
    FutureProvider.family<ManagerHotel, String>((ref, hotelId) {
  return ref.watch(getHotelDetailProvider).call(hotelId).then(
      (result) => result.fold((failure) => throw failure, (hotel) => hotel));
});

final addHotelProvider =
    FutureProvider.family<ManagerHotel, ManagerHotel>((ref, hotel) {
  return ref.watch(addHotelUseCaseProvider).call(hotel).then(
      (result) => result.fold((failure) => throw failure, (hotel) => hotel));
});
