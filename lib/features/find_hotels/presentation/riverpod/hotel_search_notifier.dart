import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/find_hotels/domain/entities/hotel_search_params.dart';
import 'package:soko_mtandao/features/find_hotels/domain/entities/hotel_search_state.dart';
import '../../domain/usecases/search_hotels.dart';

class HotelSearchNotifier extends StateNotifier<HotelSearchState> {
  final SearchHotels searchHotels;

  HotelSearchNotifier(this.searchHotels) : super(const HotelSearchState()) {
    runSearch(reset: true);
  }

  // --------------------------
  // Core Search Execution
  // --------------------------

  Future<void> runSearch({bool reset = false}) async {
    if (state.isLoading) return;

    if (reset) {
      state = state.copyWith(
        hotels: [],
        page: 1,
        hasMore: true,
      );
    }

    state = state.copyWith(isLoading: true);

    final params = HotelSearchParams(
      searchQuery: state.query,
      region: state.region,
      city: state.city,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
      guests: state.guests,
      sortOption: state.sortOption,
      page: state.page,
      limit: 20,
    );

    try {
      final results = await searchHotels(params);

      state = state.copyWith(
        hotels: reset ? results : [...state.hotels, ...results],
        isLoading: false,
        hasMore: results.length == 20,
        page: state.page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // --------------------------
  // User Actions
  // --------------------------

  void updateSearchQuery(String value) {
    state = state.copyWith(query: value);
    debounceSearch();
  }

  void updateRegion(String value) {
    state = state.copyWith(region: value);
  }

  void updateCity(String value) {
    state = state.copyWith(city: value);
  }

  void updateMinPrice(String value) {
    state = state.copyWith(minPrice: double.tryParse(value));
  }

  void updateMaxPrice(String value) {
    state = state.copyWith(maxPrice: double.tryParse(value));
  }

  void updateGuests(String value) {
    state = state.copyWith(guests: int.tryParse(value));
  }

  void updateSort(String value) {
    state = state.copyWith(sortOption: value);
    runSearch(reset: true);
  }

  void applyFilters() {
    runSearch(reset: true);
  }

  void clearFilters() {
    state = state.copyWith(
      region: "",
      city: "",
      minPrice: null,
      maxPrice: null,
      guests: null,
      sortOption: "relevance",
      page: 1,
    );

    runSearch(reset: true); // optional if you want immediate refresh
  }


  void loadMore() {
    if (!state.isLoading && state.hasMore) {
      runSearch();
    }
  }

  // --------------------------
  // Debounce for search input
  // --------------------------

  Timer? _debounce;

  void debounceSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      runSearch(reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
