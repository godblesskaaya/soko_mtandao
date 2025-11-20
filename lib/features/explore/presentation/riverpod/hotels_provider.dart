import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/explore/data/mock_datasources/mock_hotel_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../data/datasources/hotel_datasource.dart';
import '../../data/repositories/hotel_repository_impl.dart';
import '../../domain/entities/hotel.dart';
import '../../domain/usecases/get_hotel_by_id.dart';
import '../../domain/usecases/get_nearby_hotels.dart';

/// DataSource provider (mock vs real)
final hotelDataSourceProvider = Provider<HotelDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockHotelDataSource(mockState: AppConfig.globalMockState);
  }
  // Ensure Supabase is initialized in main.dart
  return SupabaseHotelDataSource();
});

/// Repository provider
final hotelRepositoryProvider = Provider((ref) {
  final ds = ref.watch(hotelDataSourceProvider);
  return HotelRepositoryImpl(ds);
});

/// Use cases
final getNearbyHotelsProvider = Provider((ref) {
  final repo = ref.watch(hotelRepositoryProvider);
  return GetNearbyHotels(repo);
});

final getHotelByIdProvider = Provider((ref) {
  final repo = ref.watch(hotelRepositoryProvider);
  return GetHotelById(repo);
});

/// State providers
final userLocationProvider = StateProvider<({double lat, double lng})>((ref) {
  // TODO: wire real location; fallback to Dar es Salaam CBD
  final location = ref.watch(locationProvider);
  if (location is AsyncData) {
    return (
      lat: location.value?.latitude ?? -6.7924,
      lng: location.value?.longitude ?? 39.2083
    );
  }
  // Fallback if location is not AsyncData
  return (
    lat: -6.7924,
    lng: 39.2083
  );
});

final hotelsProvider = FutureProvider<List<Hotel>>((ref) async {
  final loc = ref.watch(userLocationProvider);
  final usecase = ref.watch(getNearbyHotelsProvider);
  return usecase(lat: loc.lat, lng: loc.lng, radiusKm: 10);
});

final hotelDetailProvider = FutureProvider.family<Hotel, String>((ref, id) async {
  final usecase = ref.watch(getHotelByIdProvider);
  return usecase(id);
});
