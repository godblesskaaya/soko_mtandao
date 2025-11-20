import 'dart:async';
import 'dart:math';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/hotel.dart';
import '../datasources/hotel_datasource.dart';

class MockHotelDataSource implements HotelDataSource {
  final MockState mockState;
  MockHotelDataSource({this.mockState = MockState.success});

  static final _all = <Hotel>[
    // Hotel(id: 'h1', name: 'Seaside Paradise', description: 'Ocean views', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -6.7924, lng: 39.2083), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h2', name: 'City Budget Inn', description: 'Central & affordable', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -6.80,   lng: 39.25), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h3', name: 'Safari Lodge',    description: 'Near the park',       imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -6.85,   lng: 39.18), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h4', name: 'Harbor Suites',   description: 'Business district',   imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -6.77,   lng: 39.22), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h5', name: 'Zen Garden',      description: 'Boutique & calm',     imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -6.83,   lng: 39.205), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h6', name: 'Mount Meru Retreat', description: 'Lush foothills escape', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -3.3753, lng: 36.7668), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h7', name: 'Arumeru River Lodge', description: 'Tranquil riverside stay', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -3.4042, lng: 36.8056), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h8', name: 'Savannah Sunrise Lodge', description: 'Perfect for safari starters', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -3.4158, lng: 36.7821), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h9', name: 'The Coffee Estate Inn', description: 'Among Arusha’s coffee farms', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -3.3991, lng: 36.7504), totalRooms: '', availableRooms: ''),
    // Hotel(id: 'h10', name: 'Meru Forest Camp', description: 'Eco stay near forest reserve', imageUrl: 'https://placehold.co/800x400', location: HotelLocation(lat: -3.3865, lng: 36.7733), totalRooms: '', availableRooms: ''),
     
  ];

  @override
  Future<List<Hotel>> fetchNearbyHotels({required double lat, required double lng, double radiusKm = 5}) async {
    await _simulate();
    return _all.where((h) => _distanceKm(lat, lng, h.location.lat, h.location.lng) <= radiusKm).toList();
  }

  @override
  Future<List<Hotel>> fetchHotelsInBounds({required double south, required double west, required double north, required double east}) async {
    await _simulate();
    return _all.where((h) =>
      h.location.lat >= south && h.location.lat <= north &&
      h.location.lng >= west  && h.location.lng <= east
    ).toList();
  }

  @override
  Future<List<Hotel>> searchHotels({required String query, required double lat, required double lng}) async {
    await _simulate();
    final q = query.toLowerCase();
    final filtered = _all.where((h) =>
      h.name.toLowerCase().contains(q) ||
      (h.description?.toLowerCase().contains(q) ?? false)
    ).toList();
    filtered.sort((a, b) => _distanceKm(lat, lng, a.location.lat, a.location.lng)
        .compareTo(_distanceKm(lat, lng, b.location.lat, b.location.lng)));
    return filtered;
  }

  @override
  Future<Hotel> fetchHotelById(String id) async {
    await _simulate();
    return _all.firstWhere((h) => h.id == id);
  }

  Future<void> _simulate() async {
    switch (mockState) {
      case MockState.loading: await Future.delayed(const Duration(seconds: 2)); break;
      case MockState.error:   await Future.delayed(const Duration(milliseconds: 500)); throw Exception('Mock error');
      case MockState.success: await Future.delayed(const Duration(milliseconds: 250)); break;
    }
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) + cos(_deg2rad(lat1))*cos(_deg2rad(lat2))*sin(dLon/2)*sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }
  double _deg2rad(double d) => d * (3.141592653589793 / 180.0);
}
