import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/find_booking/usecases/find_booking_usecase.dart';

final findBookingProvider =
    FutureProvider.family<BookingSearchResult, String>((ref, bookingId) async {
  final usecase = FindBookingUseCase(ref.watch(bookingRepositoryProvider));
  return await usecase(bookingId);
});

final bookingHistoryProvider = FutureProvider<List<Booking>>((ref) async {
  final localBookings = await ref.watch(localBookingHistoryProvider.future);

  List<Booking> serverBookings;
  try {
    serverBookings = await ref.watch(bookingRepositoryProvider).getMyBookings();
  } catch (e, stackTrace) {
    ErrorReporter.report(
      e,
      stackTrace,
      source: 'booking_history.getMyBookings',
    );
    serverBookings = const <Booking>[];
  }

  final byId = <String, Booking>{};
  for (final booking in [...serverBookings, ...localBookings]) {
    byId.putIfAbsent(booking.id, () => booking);
  }
  return byId.values.toList(growable: false);
});
