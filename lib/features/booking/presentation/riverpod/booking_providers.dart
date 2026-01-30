import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_datasource.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_mock_datasource.dart';
import 'package:soko_mtandao/features/booking/data/datasources/booking_remote_datasource.dart';
import 'package:soko_mtandao/features/booking/data/models/booking_model.dart';
import 'package:soko_mtandao/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:soko_mtandao/features/booking/data/services/local_booking_storage_service.dart';
import 'package:soko_mtandao/features/booking/domain/entities/booking.dart';
import 'package:soko_mtandao/features/booking/domain/entities/enums.dart';
import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';
import 'package:soko_mtandao/features/booking/domain/repositories/booking_repository.dart';
import 'package:soko_mtandao/features/booking/domain/usecases/cancel_booking.dart';
import 'package:soko_mtandao/features/booking/domain/usecases/get_booking.dart';
import 'package:soko_mtandao/features/booking/domain/usecases/get_booking_status.dart';
import 'package:soko_mtandao/features/booking/domain/usecases/initiate_booking.dart';
import 'package:soko_mtandao/features/booking/presentation/riverpod/session_provider.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/riverpod/hotel_detail_provider.dart';
import '../../../hotel_detail/domain/entities/booking_input.dart';

/// DataSource selector
final bookingDataSourceProvider = Provider<BookingDataSource>((ref) {
  return AppConfig.useMockData
      ? BookingMockDataSource(mockState: AppConfig.globalMockState)
      : BookingRemoteDataSource();
});

/// Repository
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepositoryImpl(ref.watch(bookingDataSourceProvider)),
);

/// Use cases
final initiateBookingProvider = Provider((ref) => InitiateBooking(ref.watch(bookingRepositoryProvider)));
final getBookingProvider = Provider((ref) => GetBooking(ref.watch(bookingRepositoryProvider)));
final getBookingStatusProvider = Provider((ref) => GetBookingStatus(ref.watch(bookingRepositoryProvider)));
final cancelBookingProvider = Provider((ref) => CancelBooking(ref.watch(bookingRepositoryProvider)));

/// Booking Flow State
class BookingFlowState {
  final Booking? booking;
  final bool isLoading;
  final Object? error;

  BookingFlowState({this.booking, this.isLoading = false, this.error});

  BookingFlowState copyWith({Booking? booking, bool? isLoading, Object? error}) =>
      BookingFlowState(
        booking: booking ?? this.booking,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  BookingFlowNotifier(this.ref) : super(BookingFlowState());
  final Ref ref;

  Future<String?> initiate({required UserInfo user}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Pull cart from hotel detail cart state
      final cartState = ref.read(bookingCartProvider);
      if (cartState.isEmpty) throw Exception('Cart is empty');

      final sessionId = ref.read(bookingSessionProvider).id;

      final booking = await ref.read(initiateBookingProvider).call(user: user, cart: cartState.cart, sessionId: sessionId);
      state = state.copyWith(booking: booking, isLoading: false);
      return booking.id;
    } catch (e, stackTrace) {
      state = state.copyWith(isLoading: false, error: e);
      print('error initiating booking: $e');
      print(stackTrace);
      return null;
    }
  }

  Future<void> load(String bookingId, {bool saveToHistory = false}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final booking = await ref.read(getBookingProvider).call(bookingId);

      if (saveToHistory) {
        // Save to local storage
        final localStorage = ref.read(localBookingStorageProvider);
        await localStorage.saveBooking(BookingModel.fromEntity(booking));
        ref.invalidate(localBookingHistoryProvider);
      }

      state = state.copyWith(booking: booking, isLoading: false);
    } catch (e, stackTrace) {
      print('error loading booking: $e');
      print(stackTrace);
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final bookingFlowProvider =
    StateNotifierProvider.autoDispose<BookingFlowNotifier, BookingFlowState>((ref) => BookingFlowNotifier(ref));

/// Payment status polling
final paymentStatusProvider = StreamProvider.family<Booking, String>((ref, bookingId) async* {
  final getStatus = ref.read(getBookingStatusProvider);
  while (true) {
    final b = await getStatus(bookingId);
    yield b;

    if (b.paymentStatus == PaymentStatusEnum.completed &&
        b.status == BookingStatusEnum.confirmed) {
      break;
    }
    await Future.delayed(AppConfig.paymentPollInterval);
  }
});
