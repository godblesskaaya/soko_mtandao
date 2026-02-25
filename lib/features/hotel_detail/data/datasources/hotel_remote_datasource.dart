// datasources/hotel_remote_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<List<RoomModel>> fetchRoomAvailability(String hotelId, String offeringId, DateTime start, DateTime end);
}

class HotelRemoteDataSource implements HotelDetailDataSource {
  final SupabaseClient supabase = Supabase.instance.client;
  
  @override
  Future<HotelModel> fetchHotelDetail(String hotelId) async {
    return await supabase.from('hotels').select().eq('id', hotelId).single().then((value) => HotelModel.fromJson(value));
  }

  @override
  Future<List<OfferingModel>> fetchHotelOfferings(String hotelId) async {
    final response = await supabase
        .from('offerings')
        .select()
        .eq('hotel_id', hotelId)
        .order('price', ascending: true)
        .order('title', ascending: true);
    return response.map((item) => OfferingModel.fromJson(item)).toList();
  }

  @override
  Future<List<RoomModel>> fetchRoomAvailability(String hotelId, String offeringId, DateTime start, DateTime end) async {
    final response = await supabase.rpc('get_available_rooms', params: {
      'p_hotel_id': hotelId,
      'p_offering_id': offeringId,
      'p_start': start.toIso8601String(),
      'p_end': end.toIso8601String(),
    });

    final availableRooms = (response as List)
        .map((item) => RoomModel.fromJson(item))
        .toList();
    return availableRooms;
      
    }
}
