import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/booking_providers.dart';
import 'package:soko_mtandao/features/find_booking/entities/booking_search_result.dart';
import 'package:soko_mtandao/features/find_booking/usecases/find_booking_usecase.dart';

final findBookingProvider =
  FutureProvider.family<BookingSearchResult, String>((ref, bookingId) async {
  final usecase = FindBookingUseCase(ref.watch(bookingRepositoryProvider));
  return await usecase(bookingId);
});
