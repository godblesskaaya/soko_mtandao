import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/hotel.dart';

abstract class HotelDataSource {
  Future<List<Hotel>> fetchNearbyHotels({
    required double lat,
    required double lng,
    double radiusKm,
  });

  Future<List<Hotel>> fetchHotelsInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  });

  Future<List<Hotel>> searchHotels({
    required String query,
    required double lat,
    required double lng,
  });

  Future<Hotel> fetchHotelById(String id);
}

class SupabaseHotelDataSource implements HotelDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<Hotel>> fetchNearbyHotels({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    // Example: using a “hotels” table/view with (id, name, description, lat, lng, image_url, is_active)
    final res = await _client
        .from('hotels')
        .select()
        // .eq('is_active', true)
        .limit(300);

    final all = _mapRows(res);
    return all.where((h) => _distanceKm(lat, lng, h.location.lat, h.location.lng) <= radiusKm).toList();
  }

  @override
  Future<List<Hotel>> fetchHotelsInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final res = await _client
        .rpc('get_hotels_in_bounding_box', params: {
          'north': north,
          'south': south,
          'east': east,
          'west': west,
        });

        print(res);

    return _mapRows(res);
  }

  @override
  Future<List<Hotel>> searchHotels({
    required String query,
    required double lat,
    required double lng,
  }) async {
    // Simple ilike search + client-side sort by distance
    final res = await _client
        .from('hotels')
        .select()
        .or('name.ilike.%$query%,description.ilike.%$query%')
        // .eq('is_active', true)
        .limit(200);

    final hotels = _mapRows(res);
    hotels.sort((a, b) {
      final da = _distanceKm(lat, lng, a.location.lat, a.location.lng);
      final db = _distanceKm(lat, lng, b.location.lat, b.location.lng);
      return da.compareTo(db);
    });
    return hotels;
  }

  @override
  Future<Hotel> fetchHotelById(String id) async {
    final row = await _client.from('hotels').select().eq('id', id).maybeSingle();
    if (row == null) throw Exception('Hotel not found');
    return _rowToHotel(row);
  }

  List<Hotel> _mapRows(List<dynamic> rows) => rows.map(_rowToHotel).toList();

  Hotel _rowToHotel(dynamic row) => Hotel(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        imageUrl: row['image_url'] as String?,
        location: HotelLocation(
          lat: (row['lat'] as num).toDouble(),
          lng: (row['lng'] as num).toDouble(),
        ),
        totalRooms: row['total_rooms'],
        availableRooms: row['available_rooms'] ?? 0,
      );

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
