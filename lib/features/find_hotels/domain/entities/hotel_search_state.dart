import '../../domain/entities/hotel_entity.dart';
import 'package:soko_mtandao/core/errors/failures.dart';

class HotelSearchState {
  final List<HotelEntity> hotels;
  final bool isLoading;
  final Failure? error;
  final bool hasMore;
  final int page;

  // Filters
  final String query;
  final String region;
  final String city;
  final double? minPrice;
  final double? maxPrice;
  final int? guests;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String sortOption;

  const HotelSearchState({
    this.hotels = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.query = "",
    this.region = "",
    this.city = "",
    this.minPrice,
    this.maxPrice,
    this.guests,
    this.checkIn,
    this.checkOut,
    this.sortOption = "relevance",
  });

  HotelSearchState copyWith({
    List<HotelEntity>? hotels,
    bool? isLoading,
    Failure? error,
    bool clearError = false,
    bool? hasMore,
    int? page,
    String? query,
    String? region,
    String? city,
    double? minPrice,
    double? maxPrice,
    int? guests,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearGuests = false,
    DateTime? checkIn,
    DateTime? checkOut,
    bool clearCheckIn = false,
    bool clearCheckOut = false,
    String? sortOption,
  }) {
    return HotelSearchState(
      hotels: hotels ?? this.hotels,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      query: query ?? this.query,
      region: region ?? this.region,
      city: city ?? this.city,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      guests: clearGuests ? null : (guests ?? this.guests),
      checkIn: clearCheckIn ? null : (checkIn ?? this.checkIn),
      checkOut: clearCheckOut ? null : (checkOut ?? this.checkOut),
      sortOption: sortOption ?? this.sortOption,
    );
  }
}
