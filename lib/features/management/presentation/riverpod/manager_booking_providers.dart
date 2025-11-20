// presentation/riverpod/bookings/booking_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_item_model.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/bookings/get_booking_detail.dart';
import 'package:soko_mtandao/features/management/domain/usecases/bookings/get_bookings.dart';
import 'package:soko_mtandao/features/management/domain/usecases/bookings/get_bookings_for_room.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';

final getBookingItemsProvider = Provider<GetBookingItems>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetBookingItems(repo);
});

final bookingsProvider = FutureProvider.family<List<ManagerBookingItem>, BookingQueryParams>((ref, params) {
  return ref.watch(getBookingItemsProvider).call(params).then((result) =>
    result.fold((failure) => throw failure, (bookings) => bookings)
  );
});

final getBookingDetailProvider = Provider<GetBookingDetail>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetBookingDetail(repo);
});

final bookingDetailProvider = FutureProvider.family<ManagerBooking, String>((ref, bookingId) {
  return ref.watch(getBookingDetailProvider).call(bookingId).then((result) =>
    result.fold((failure) => throw failure, (booking) => booking)
  );
});

final bookingListCombinedProvider = FutureProvider.family<List<BookingWithRoomAndDetail>, String>((ref, hotelId) async {
  final bookings = await ref.watch(bookingsProvider(BookingQueryParams(hotelId: hotelId, filters: {})).future);

  final results = <BookingWithRoomAndDetail>[];

  for (final b in bookings) {
    final room = await ref.watch(roomProvider(b.roomId ?? '').future);
    final detail = await ref.watch(bookingDetailProvider(b.bookingId ?? '').future);
    results.add(BookingWithRoomAndDetail(
      booking: b,
      room: room,
      detail: detail,
    ));
  }

  return results;
});

final getRoomBookingsProvider = Provider<GetBookingItemsForRoom>((ref) {
  final repo = ref.watch(managerRepositoryProvider);
  return GetBookingItemsForRoom(repo);
});

final roomBookingsProvider = FutureProvider.family<List<ManagerBookingItem>, String>((ref, roomId) {
  return ref.watch(getRoomBookingsProvider).call(roomId).then((result) =>
    result.fold((failure) => throw failure, (bookings) => bookings)
  );
});


class BookingWithRoomAndDetail {
  final ManagerBookingItem booking;
  final ManagerRoom room;
  final ManagerBooking detail;

  BookingWithRoomAndDetail({
    required this.booking,
    required this.room,
    required this.detail,
  });
}