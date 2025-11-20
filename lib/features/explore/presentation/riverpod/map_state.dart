import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../data/datasources/hotel_datasource.dart';
import '../../data/mock_datasources/mock_hotel_datasource.dart';
import '../../data/repositories/hotel_repository_impl.dart';
import '../../domain/entities/hotel.dart';
import '../../domain/usecases/get_hotels_in_bounds.dart';
import '../../domain/usecases/search_hotels.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === DI: data source / repo / use cases
final hotelDataSourceProvider = Provider<HotelDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockHotelDataSource(mockState: AppConfig.globalMockState);
  }
  return SupabaseHotelDataSource();
});
final hotelRepositoryProvider = Provider((ref) => HotelRepositoryImpl(ref.watch(hotelDataSourceProvider)));
final getHotelsInBoundsProvider = Provider((ref) => GetHotelsInBounds(ref.watch(hotelRepositoryProvider)));
final searchHotelsProvider = Provider((ref) => SearchHotels(ref.watch(hotelRepositoryProvider)));

// === User location
final initialLocationProvider = FutureProvider<({double lat, double lng})>((ref) async {
  final loc = await LocationService().getCurrentPositionOrFallback();
  return loc;
});

// === Map camera state
class CameraState {
  final double lat;
  final double lng;
  final double zoom;
  final ({double south, double west, double north, double east}) bounds;
  const CameraState({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.bounds,
  });
}

// Hold last known camera; start with fallback while loading GPS
final cameraStateProvider = StateProvider<CameraState?>((ref) => null);

// Selected hotel pin
final selectedHotelIdProvider = StateProvider<String?>((ref) => null);

// Search query
final exploreSearchQueryProvider = StateProvider<String>((ref) => '');

// Hotels list (drives list + pins). We refetch when camera moves far enough or zoom changes meaningfully.
final hotelsInViewProvider = FutureProvider.autoDispose<List<Hotel>>((ref) async {
  final camera = ref.watch(cameraStateProvider);
  final query = ref.watch(exploreSearchQueryProvider);

  // If camera not ready yet, wait for initial location
  if (camera == null) {
    final loc = await ref.watch(initialLocationProvider.future);
    // prime an initial bounds roughly around location
    final lat = loc.lat, lng = loc.lng;
    final bounds = (south: lat - 0.03, west: lng - 0.03, north: lat + 0.03, east: lng + 0.03);
    final initial = CameraState(lat: lat, lng: lng, zoom: MapConfig.minZoomForData + 1, bounds: bounds);
    ref.read(cameraStateProvider.notifier).state = initial;
    // fall through; we’ll fetch on next recompute
    return [];
  }

  // If zoom is too low – pause
  if (camera.zoom < MapConfig.minZoomForData) {
    return [];
  }

  // If user typed a query -> search
  if (query.trim().isNotEmpty) {
    final search = ref.read(searchHotelsProvider);
    final list = await search(query: query.trim(), lat: camera.lat, lng: camera.lng);
    return list;
  }

  // Otherwise fetch by bounds
  final usecase = ref.read(getHotelsInBoundsProvider);
  final b = camera.bounds;
  final list = await usecase(south: b.south, west: b.west, north: b.north, east: b.east);
  return list;
});
