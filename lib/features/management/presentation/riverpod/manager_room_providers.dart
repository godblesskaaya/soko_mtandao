// presentation/riverpod/rooms/room_providers.dart

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/add_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/get_room_availability.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/get_room_by_id.dart';
import 'package:soko_mtandao/features/management/domain/usecases/rooms/get_rooms.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';

class ManagerRoomListQuery {
  final String hotelId;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAscending;
  final bool? isActive;

  const ManagerRoomListQuery({
    required this.hotelId,
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'room_number',
    this.sortAscending = true,
    this.isActive,
  });

  int get offset => (page - 1) * limit;

  RoomParams get params => RoomParams(
        hotelId: hotelId,
        filters: {
          'limit': limit,
          'offset': offset,
          'sort_by': sortBy,
          'sort_asc': sortAscending,
          if (isActive != null) 'is_active': isActive,
        },
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ManagerRoomListQuery &&
            runtimeType == other.runtimeType &&
            hotelId == other.hotelId &&
            page == other.page &&
            limit == other.limit &&
            sortBy == other.sortBy &&
            sortAscending == other.sortAscending &&
            isActive == other.isActive;
  }

  @override
  int get hashCode =>
      Object.hash(hotelId, page, limit, sortBy, sortAscending, isActive);
}

final getRoomsForOfferingProvider = Provider<GetRooms>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetRooms(repo);
});

final roomsPageProvider =
    FutureProvider.family<List<ManagerRoom>, ManagerRoomListQuery>(
        (ref, query) {
  return ref.watch(getRoomsForOfferingProvider).call(query.params).then(
      (result) => result.fold((failure) => throw failure, (rooms) => rooms));
});

final roomsProvider =
    FutureProvider.family<List<ManagerRoom>, String>((ref, hotelId) {
  return ref
      .watch(roomsPageProvider(ManagerRoomListQuery(hotelId: hotelId)).future);
});

final getRoomAvailabilityProvider = Provider<GetRoomAvailability>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetRoomAvailability(repo);
});

final roomAvailabilityProvider = FutureProvider.family
    .autoDispose<RoomAvailability, AvailabilityParams>((ref, params) {
  return ref.watch(getRoomAvailabilityProvider).call(params).then((result) =>
      result.fold((failure) => throw failure, (availability) => availability));
});

final roomProvider = FutureProvider.family<ManagerRoom, String>((ref, roomId) {
  final repo = ref.watch(managerRepositoryProvider);
  final getRoomById = GetRoomById(repo);
  return getRoomById.call(roomId).then(
      (result) => result.fold((failure) => throw failure, (room) => room));
});

final addRoomUseCaseProvider = Provider<AddRoom>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return AddRoom(repo);
});

final addRoomProvider = StateNotifierProvider<AddRoomNotifier,
    AsyncValue<Either<Failure, ManagerRoom>?>>((ref) {
  final usecase = ref.read(addRoomUseCaseProvider);
  return AddRoomNotifier(usecase);
});

class AddRoomNotifier
    extends StateNotifier<AsyncValue<Either<Failure, ManagerRoom>?>> {
  final AddRoom _useCase;

  AddRoomNotifier(this._useCase) : super(const AsyncData(null));

  Future<void> addRoom(ManagerRoom room) async {
    state = const AsyncLoading();
    final result = await _useCase(room);
    state = AsyncData(result);
  }
}
