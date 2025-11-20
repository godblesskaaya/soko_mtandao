import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:soko_mtandao/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/usecases/monitor_booking_payment.dart';

final bookingRepositoryProvider = Provider((ref) {
  final ds = BookingRemoteDataSource();
  return BookingRepositoryImpl(ds);
});

final monitorBookingPaymentProvider = Provider((ref) {
  final repo = ref.watch(bookingRepositoryProvider);
  return MonitorBookingPayment(repo);
});

final bookingPaymentStreamProvider =
    StreamProvider.family<Booking, String>((ref, bookingId) {
  final monitor = ref.watch(monitorBookingPaymentProvider);
  return monitor(bookingId);
});
