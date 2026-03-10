// datasources/hotel_remote_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/core/utils/stay_dates.dart';

import '../models/hotel_model.dart';
import '../models/offering_model.dart';
import '../models/room_model.dart';

abstract class HotelDetailDataSource {
  /// Fetch single hotel details (name, description, images, etc.)
  Future<HotelModel> fetchHotelDetail(String hotelId);

  // /// Fetch hotel amenities (wifi, parking, etc.)
  // Future<List<String>> getHotelAmenities(String hotelId);

  /// Fetch offerings for a given date range
  Future<List<OfferingModel>> fetchHotelOfferings(String hotelId);

  /// Fetch room availability for a specific offering & date
  Future<List<RoomModel>> fetchRoomAvailability(
      String hotelId, String offeringId, DateTime start, DateTime end);
}

class HotelRemoteDataSource implements HotelDetailDataSource {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _castRows(dynamic response) {
    return List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Map<String, dynamic>? _extractAmenityMap(dynamic row) {
    if (row is! Map) return null;
    final raw = row['amenities'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw as Map);
  }

  @override
  Future<HotelModel> fetchHotelDetail(String hotelId) async {
    final hotelRow =
        await supabase.from('hotels').select().eq('id', hotelId).single();
    final amenityRows = await supabase
        .from('hotel_amenities')
        .select('amenities:amenity_id(amenity_id,name,icon_url)')
        .eq('hotel_id', hotelId);

    final amenities = _castRows(amenityRows)
        .map(_extractAmenityMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final enriched = Map<String, dynamic>.from(hotelRow as Map)
      ..['amenities'] = amenities;
    return HotelModel.fromJson(enriched);
  }

  @override
  Future<List<OfferingModel>> fetchHotelOfferings(String hotelId) async {
    final response = await supabase
        .from('offerings')
        .select()
        .eq('hotel_id', hotelId)
        .order('price', ascending: true)
        .order('title', ascending: true);

    final offerings = _castRows(response);
    final offeringIds = offerings
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final amenitiesByOffering = <String, List<Map<String, dynamic>>>{};
    if (offeringIds.isNotEmpty) {
      final amenityRows = await supabase
          .from('offering_amenities')
          .select('offering_id, amenities:amenity_id(amenity_id,name,icon_url)')
          .inFilter('offering_id', offeringIds);

      for (final row in _castRows(amenityRows)) {
        final offeringId = (row['offering_id'] ?? '').toString();
        final amenity = _extractAmenityMap(row);
        if (offeringId.isEmpty || amenity == null) continue;
        final bucket = amenitiesByOffering.putIfAbsent(
            offeringId, () => <Map<String, dynamic>>[]);
        bucket.add(amenity);
      }
    }

    return offerings.map((row) {
      final id = (row['id'] ?? '').toString();
      final enriched = Map<String, dynamic>.from(row)
        ..putIfAbsent('images', () => const <String>[])
        ..['amenities'] =
            amenitiesByOffering[id] ?? const <Map<String, dynamic>>[];
      return OfferingModel.fromJson(enriched);
    }).toList(growable: false);
  }

  @override
  Future<List<RoomModel>> fetchRoomAvailability(
      String hotelId, String offeringId, DateTime start, DateTime end) async {
    final response = await supabase.rpc('get_available_rooms', params: {
      'p_hotel_id': hotelId,
      'p_offering_id': offeringId,
      'p_start': formatYmd(start),
      'p_end': formatYmd(end),
    });

    final availableRooms =
        (response as List).map((item) => RoomModel.fromJson(item)).toList();
    return availableRooms;
  }
}
