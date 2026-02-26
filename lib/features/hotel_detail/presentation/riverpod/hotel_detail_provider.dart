// hotel_detail_providers.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/features/hotel_detail/data/datasources/hotel_mock_datasource.dart';
import 'package:soko_mtandao/features/hotel_detail/data/datasources/hotel_remote_datasource.dart';
import 'package:soko_mtandao/features/hotel_detail/data/repositories/hotel_repository_impl.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_cart.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_input.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/booking_item_input.dart';
import '../../domain/entities/hotel.dart';
import '../../domain/entities/offering.dart';
import '../../domain/entities/room.dart';
import '../../domain/usecases/get_hotel_detail.dart';
import '../../domain/usecases/get_hotel_offerings.dart';
import '../../domain/usecases/get_room_availability.dart';

/// DataSource provider (mock vs real)
final hotelDataSourceProvider = Provider<HotelDetailDataSource>((ref) {
  if (AppConfig.useMockData) {
    return HotelMockDataSource(mockState: AppConfig.globalMockState);
  }
  // Ensure Supabase is initialized in main.dart this is the real data source
  // that connects to the backend.
  return HotelRemoteDataSource();
});

/// Hotel Detail Repository provider
final hotelDetailRepositoryProvider = Provider((ref) {
  final ds = ref.watch(hotelDataSourceProvider);
  return HotelRepositoryImpl(ds);
});

/// Use case providers
final getHotelDetailUseCaseProvider = Provider((ref) {
  final repo = ref.watch(hotelDetailRepositoryProvider);
  return GetHotelDetail(repo);
});

final getHotelOfferingsUseCaseProvider = Provider((ref) {
  final repo = ref.watch(hotelDetailRepositoryProvider);
  return GetHotelOfferings(repo);
});

final getRoomAvailabilityUseCaseProvider = Provider((ref) {
  final repo = ref.watch(hotelDetailRepositoryProvider);
  return GetRoomAvailability(repo);
});

/// -------------------------
/// HOTEL DETAIL PROVIDER
/// -------------------------
final hotelDetailProvider =
    FutureProvider.family<Hotel, String>((ref, hotelId) async {
  final usecase = ref.read(getHotelDetailUseCaseProvider);
  return await usecase(hotelId);
});

/// -------------------------
/// HOTEL AMENITIES
/// -------------------------
final hotelAmenitiesProvider =
    FutureProvider.family<List<Amenity>, String>((ref, hotelId) async {
  final usecase = ref.read(getHotelDetailUseCaseProvider);
  return await usecase(hotelId).then((hotel) => hotel.amenities);
});

/// -------------------------
/// OFFERINGS (depends on hotel)
/// -------------------------
final offeringProvider =
    FutureProvider.family<List<Offering>, String>((ref, hotelId) async {
  final usecase = ref.read(getHotelOfferingsUseCaseProvider);
  return await usecase(hotelId);
});

/// -------------------------
/// OFFERING AMENITIES
/// -------------------------
final offeringAmenitiesProvider =
    FutureProvider.family<List<Amenity>, ({String hotelId, String offeringId})>(
        (ref, params) async {
  final offeringId = params.offeringId;
  final usecase = ref.read(getHotelOfferingsUseCaseProvider);
  return await usecase(params.hotelId).then((offerings) {
    final offering = offerings.firstWhere((o) => o.id == offeringId);
    return offering.amenities;
  });
});

/// -------------------------
/// ROOM AVAILABILITY (on-demand)
/// -------------------------
final roomAvailabilityProvider = FutureProvider.family<
    List<Room>,
    ({
      String hotelId,
      String offeringId,
      DateTime startdate,
      DateTime enddate,
    })>((ref, params) async {
  final hotelId = params.hotelId;
  final offeringId = params.offeringId;
  final usecase = ref.read(getRoomAvailabilityUseCaseProvider);
  return await usecase(hotelId, offeringId, params.startdate, params.enddate);
});

/// -------------------------
/// SELECTED ROOM STATE
/// -------------------------
final selectedRoomProvider = StateProvider<Room?>((ref) => null);

/// -------------------------
/// BOOKING CART (multi-room)
/// -------------------------
final bookingCartProvider =
    StateNotifierProvider<BookingCartNotifier, BookingCartState>(
  (ref) => BookingCartNotifier(),
);

class BookingCartState {
  final BookingCart cart; // List of all bookings (already grouped by hotel)

  const BookingCartState({required this.cart});

  factory BookingCartState.initial() {
    return BookingCartState(cart: BookingCart());
  }

  bool get isEmpty => cart.isEmpty;

  int get totalItems => cart.totalItems;

  double get totalPrice => cart.totalPrice;
}

class BookingCartNotifier extends StateNotifier<BookingCartState> {
  BookingCartNotifier() : super(BookingCartState.initial());

// Create a new booking for a hotel
  void addRoom({
    required BookingInput booking,
    required BookingItemInput item,
  }) {
    try {
      state = BookingCartState(
        cart: state.cart.addItem(
          booking: booking,
          item: item,
        ),
      );
    } on StateError catch (e) {
      // Handle error if room already exists in booking
      rethrow;
    }
  }

  void removeRoom({
    required String bookingId,
    required String roomId,
  }) {
    state = BookingCartState(
      cart: state.cart.removeItem(
        bookingId: bookingId,
        roomId: roomId,
      ),
    );
  }

  void clearCart() {
    state = BookingCartState.initial();
  }
}
