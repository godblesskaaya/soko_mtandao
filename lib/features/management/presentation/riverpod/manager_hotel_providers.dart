// presentation/riverpod/hotels/hotel_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/add_hotel.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_hotels_for_manager.dart';
import 'package:soko_mtandao/features/management/domain/usecases/hotels/get_hotel_detail.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

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
final managerHotelsProvider = FutureProvider.family<List<ManagerHotel>, String>((ref, managerUserId) {
  return ref.watch(getHotelsForManagerProvider).call(managerUserId).then((result) =>
    result.fold((failure) => throw failure, (hotels) => hotels)
  );
});

final hotelDetailProvider = FutureProvider.family<ManagerHotel, String>((ref, hotelId) {
  return ref.watch(getHotelDetailProvider).call(hotelId).then((result) =>
    result.fold((failure) => throw failure, (hotel) => hotel)
  );
});

final addHotelProvider = FutureProvider.family<ManagerHotel, ManagerHotel>((ref, hotel) {
  return ref.watch(addHotelUseCaseProvider).call(hotel).then((result) =>
    result.fold((failure) => throw failure, (hotel) => hotel)
  );
});
