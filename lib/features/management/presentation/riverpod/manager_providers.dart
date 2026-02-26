import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/entities/staff_member.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/manager_datasource.dart';
import '../../data/datasources/manager_remote_datasource.dart';
import '../../data/repositories/manager_repository_impl.dart';
import '../../domain/repositories/manager_repository.dart';

// select datasource
final managerDataSourceProvider = Provider<ManagerDataSource>((ref) {
  return /* AppConfig.useMockData ? ManagerMockDataSource(mockState: AppConfig.globalMockState) :  */ ManagerRemoteDataSource();
});

// repo
final managerRepositoryProvider = Provider<ManagerRepository>(
    (ref) => ManagerRepositoryImpl(ref.watch(managerDataSourceProvider)));

// Providers used by UI
final managerHotelListProvider =
    FutureProvider.family<List<ManagerHotel>, String>(
        (ref, managerUserId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getManagedHotels(managerUserId);
});

final managerOfferingsProvider =
    FutureProvider.family<List<ManagerOffering>, String>((ref, hotelId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getOfferings(hotelId);
});

// get rooms by hotelId and optional filters
final managerRoomsFiltersProvider =
    StateProvider<Map<String, dynamic>>((ref) => {
          // return map of filters connected to UI elements
          'priceRange': [0, 500], // Example price range filter
          'rating': 4, // Example rating filter
          'location': 'cityCenter' // Example location filter
        });

final managerRoomsProvider =
    FutureProvider.family<List<ManagerRoom>, String>((ref, hotelId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getRooms(hotelId, ref.watch(managerRoomsFiltersProvider));
});

final managerProfileProvider = FutureProvider<User>((ref) async {
  final user = ref.watch(authServiceProvider).currentUser!;
  return user;
});

class ManagerProfileUpdateInput {
  final String firstName;
  final String lastName;
  final String phone;
  final String title;
  final String bio;

  const ManagerProfileUpdateInput({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.title = '',
    this.bio = '',
  });
}

class ManagerProfileUpdateNotifier extends StateNotifier<AsyncValue<User?>> {
  final ManagerRepository _repository;
  final Ref _ref;

  ManagerProfileUpdateNotifier(this._repository, this._ref)
      : super(const AsyncData(null));

  Future<User> update(ManagerProfileUpdateInput input) async {
    state = const AsyncLoading();
    try {
      final updatedUser = await _repository.updateManagerProfile(
        firstName: input.firstName,
        lastName: input.lastName,
        phone: input.phone,
        title: input.title,
        bio: input.bio,
      );
      _ref.invalidate(managerProfileProvider);
      state = AsyncData(updatedUser);
      return updatedUser;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final managerProfileUpdateProvider =
    StateNotifierProvider<ManagerProfileUpdateNotifier, AsyncValue<User?>>(
        (ref) {
  final repository = ref.watch(managerRepositoryProvider);
  return ManagerProfileUpdateNotifier(repository, ref);
});

final managerBookingsFiltersProvider =
    StateProvider<Map<String, dynamic>>((ref) => {
          // return map of filters connected to UI elements
          'dateRange': [
            DateTime.now(),
            DateTime.now().add(Duration(days: 7))
          ], // Example date range filter
          'status': 'confirmed', // Example status filter
        });

final managerBookingListProvider =
    FutureProvider.family<List<ManagerBookingItem>, String>(
        (ref, hotelId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getBookings(
      hotelId: hotelId, filters: ref.watch(managerBookingsFiltersProvider));
});

final managerStaffProvider =
    FutureProvider.family<List<StaffMember>, String>((ref, hotelId) async {
  final repo = ref.watch(managerRepositoryProvider);
  return repo.getStaff(hotelId);
});
