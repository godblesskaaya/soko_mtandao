// hotel_detail_providers.dart
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
final offeringProvider = FutureProvider.family<List<Offering>, String>(
    (ref, hotelId) async {
  final usecase = ref.read(getHotelOfferingsUseCaseProvider);
  return await usecase(hotelId);
});

/// -------------------------
/// OFFERING AMENITIES
/// -------------------------
final offeringAmenitiesProvider =
    FutureProvider.family<List<Amenity>, ({String hotelId, String offeringId})>((ref, params) async {
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
final roomAvailabilityProvider =
    FutureProvider.family<List<Room>, ({
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
final bookingCartProvider = StateNotifierProvider<BookingCartNotifier, BookingCartState>(
  (ref) => BookingCartNotifier(),
);

// class BookingCartNotifier extends StateNotifier<List<BookingItemInput>> {
//   BookingCartNotifier() : super([]);

//   void addItem(BookingItemInput item) {
//     state = [...state, item];
//   }

//   void removeItem(String roomId) {
//     state = state.where((i) => i.room.id != roomId).toList();
//   }

//   void clear() => state = [];
// }


/// ------------------------------------
/// BOOKING CART PROVIDER
/// ------------------------------------
// class BookingCartState {
//   final BookingCart? cart;

//   BookingCartState({this.cart});

//   BookingCartState copyWith({BookingCart? cart}) {
//     return BookingCartState(cart: cart ?? this.cart);
//   }
// }
class BookingCartState extends BookingCart {
  @override
  final List<BookingInput> bookings;  // List of all bookings (already grouped by hotel)

  BookingCartState({this.bookings = const []}) : super(bookings: []);

  @override
  BookingCartState copyWith({List<BookingInput>? bookings}) {
    return BookingCartState(
      bookings: bookings ?? this.bookings,
    );
  }

  @override
  bool get isEmpty => bookings.isEmpty;
  @override
  int get totalItems => bookings.fold(0, (sum, booking) => sum + booking.totalItems);

// calculate total price based on bookings in cart
  @override
  double get totalPrice {
    return bookings.fold(0, (sum, booking) => sum + booking.totalPrice);
  }

}


class BookingCartNotifier extends StateNotifier<BookingCartState> {
  BookingCartNotifier() : super(BookingCartState());

// Create a new booking for a hotel
  void createBooking({
    required Hotel hotel,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final newBooking = BookingInput(
      hotel: hotel,
      startDate: startDate,
      endDate: endDate,
      items: [],
    );

    // Add the new booking to the cart
    state = state.copyWith(
      bookings: [...state.bookings, newBooking],
    );
  }

  // Add a room (BookingItemInput) to a specific booking
  Future<void> addItemToBooking({
    required String hotelId,
    required DateTime startDate,
    required DateTime endDate,
    required BookingItemInput item,
    required WidgetRef ref,
  }) async {
    final hotel = await ref.read(hotelDetailProvider(hotelId).future); // Inject ref in constructor

    final List<BookingInput> currentCart = state.bookings ?? [];

    // Try to find existing booking
    final existingBookingIndex = currentCart.indexWhere((booking) =>
      booking.hotel.id == hotelId &&
      booking.startDate == startDate &&
      booking.endDate == endDate,
    );

    final bookingItem = item;

    if (existingBookingIndex != -1) {
      // Modify existing booking
      final existingBooking = currentCart[existingBookingIndex];
      final updatedBooking = existingBooking.copyWith(
        items: [...existingBooking.items, bookingItem],
      );

      final updatedItems = [...currentCart];
      updatedItems[existingBookingIndex] = updatedBooking;

      state = state.copyWith(bookings: updatedItems);
    } else {
      // if item is null dont create a new booking
      if (hotel == null || item == null) return;
      // Create new booking
      final newBooking = BookingInput(
        hotel: hotel,
        startDate: startDate,
        endDate: endDate,
        items: [bookingItem],
      );

      state = state.copyWith(bookings: [...currentCart, newBooking]);
    }
  }

  // Remove a room (BookingItemInput) from a specific booking
  void removeItemFromBooking(BookingInput booking, BookingItemInput item) {
    final updatedBookings = state.bookings.map((b) {
      if (b == booking) {
        final updatedItems = b.items.where((i) => i != item).toList();
        // If the booking becomes empty, we return null (indicating it should be removed)
        if (updatedItems.isEmpty) {
          return null;
        }
        return b.copyWith(items: updatedItems);
      }
      return b;
    }).where((b) => b != null).cast<BookingInput>().toList();

    state = state.copyWith(bookings: updatedBookings);
  }

  // Remove an entire booking from the cart for a specific hotel
  void removeBooking(BookingInput booking) {
    final updatedBookings = state.bookings.where((b) => b != booking).toList();

    state = state.copyWith(bookings: updatedBookings);
  }

  // Clear the entire cart (remove all bookings across all hotels)
  void clearCart() {
    state = state.copyWith(bookings: []);
  }

  // Get the total price for all bookings across all hotels
  double get totalPrice {
    return state.bookings.fold(0, (sum, booking) => sum + booking.totalPrice);
  }

  // Get the bookings for a specific hotel (if needed)
  List<BookingInput> getBookingsForHotel(String hotelId) {
    return state.bookings.where((booking) => booking.hotel.id == hotelId).toList();
  }  

//   void createCart({
//     required Hotel hotel,
//     required DateTime startDate,
//     required DateTime endDate,
//   }) {
//     state = state.copyWith(
//       cart: BookingCart(
//         items: [],
//         hotel: hotel,
//         startDate: startDate,
//         endDate: endDate,
//       ),
//     );
//   }

//   void addToCart(BookingItemInput booking) {
//     final currentCart = state.cart;
//     if (currentCart == null) return;

//     final updatedItems = [...currentCart.items, booking];
//     state = state.copyWith(
//       cart: currentCart.copyWith(items: updatedItems),
//     );
//   }

//   void removeFromCart(BookingItemInput booking) {
//     final currentCart = state.cart;
//     if (currentCart == null) return;

//     final updatedItems = currentCart.items.where((b) => b != booking).toList();
//     state = state.copyWith(
//       cart: currentCart.copyWith(items: updatedItems),
//     );
//   }

//   void clearCart() {
//     state = state.copyWith(cart: null);
//   }
}
