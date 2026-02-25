// supabase implementation of manager datasource
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/features/management/data/models/manager_amenity_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_item_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_hotel_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_offering_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_payment_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_room_model.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/entities/staff_member.dart';
import 'manager_datasource.dart';

class ManagerRemoteDataSource implements ManagerDataSource {
    final SupabaseClient _supabase = Supabase.instance.client;

  ManagerRemoteDataSource();

  @override
  Future<List<ManagerHotelModel>> fetchManagedHotels(String managerUserId, {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'name', 'created_at', 'rating', 'city'};
    final sortBy = allowedSort.contains(normalized['sort_by']) ? normalized['sort_by'] as String : 'name';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isActive = normalized['is_active'] as bool?;

    dynamic query = _supabase
        .from('hotels')
        .select()
        .eq('manager_user_id', managerUserId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;

    return response.map((e) => ManagerHotelModel.fromJson(e)).toList();
  }

  @override
  Future<ManagerHotelModel> createHotel(ManagerHotel hotel) async {
    final AuthService authService = AuthService();
    final response = await _supabase.from('hotels').insert({
      "name": hotel.name,
      "address": hotel.address,
      "description": hotel.description,
      "images": hotel.images, // ✅ remote URLs, not local paths
      "location": 'SRID=4326;POINT(${hotel.lng} ${hotel.lat})',
      "rating": hotel.rating,
      "total_rooms": hotel.totalRooms,
      "region": hotel.region,
      "country": hotel.country,
      "city": hotel.city,
      "phone_number": hotel.phoneNumber,
      "email": hotel.email,
      "website": hotel.website,
      "is_active": true,
      // "amenities": hotel.amenities.map((a) => a.name).toList(),
      "manager_user_id": authService.userId,
    }).select().single();

    return ManagerHotelModel.fromJson(response);

  }

  @override
  Future<ManagerHotelModel> updateHotel(ManagerHotel hotel) async {
    // TODO: implement updateHotel
    throw UnimplementedError();
  }
  
  @override
  Future<void> cancelBooking(String bookingId) {
    // TODO: implement cancelBooking
    throw UnimplementedError();
  }
  
  @override
  Future<void> changeStaffRole(String staffId, String role) {
    // TODO: implement changeStaffRole
    throw UnimplementedError();
  }
  
  @override
  Future<ManagerOfferingModel> createOffering(ManagerOffering offering) async{
    final response = await _supabase.from('offerings')
        .insert(ManagerOfferingModel.fromEntity(offering).toJson())
        .select()
        .single();

    return ManagerOfferingModel.fromJson(response);
  }
  
  @override
  Future<ManagerRoomModel> createRoom(ManagerRoom room) async {
    final response = await _supabase.from('hotel_rooms')
        .insert(ManagerRoomModel.fromEntity(room).toJson())
        .select()
        .single();

    return ManagerRoomModel.fromJson(response);
  }
  
  @override
  Future<void> deactivateHotel(String hotelId) {
    // TODO: implement deactivateHotel
    throw UnimplementedError();
  }
  
  @override
  Future<void> deleteOffering(String offeringId) async{
    await _supabase.from('offerings')
        .delete()
        .eq('id', offeringId);
  }
  
  @override
  void deleteRoom(String roomId) async{
    await _supabase.from('hotel_rooms')
        .delete()
        .eq('id', roomId);
  }
  
  @override
  Future<ManagerBookingModel> fetchBookingDetail(String bookingId) async {
    final response = await _supabase
        .from('bookings')
        .select()
        .eq('id', bookingId);

    return ManagerBookingModel.fromJson(response.first);
  }
  
  @override
  Future<List<ManagerBookingItemModel>> fetchBookings(String hotelId, {Map<String, dynamic>? filters}) {
    // TODO: implement fetchBookings
    throw UnimplementedError();
  }
  
  @override
  Future<List<ManagerOfferingModel>> fetchOfferings(String hotelId, {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'title', 'price', 'max_guests', 'created_at', 'is_available'};
    final sortBy = allowedSort.contains(normalized['sort_by']) ? normalized['sort_by'] as String : 'title';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isAvailable = normalized['is_available'] as bool?;

    dynamic query = _supabase
        .from('offerings')
        .select()
        .eq('hotel_id', hotelId);

    if (isAvailable != null) {
      query = query.eq('is_available', isAvailable);
    }
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;

    return response.map((e) => ManagerOfferingModel.fromJson(e)).toList();
                    
  }

  @override
  Future<ManagerOffering> fetchOfferingById(String offeringId) async {
    final response = await _supabase
        .from('offerings')
        .select()
        .eq('id', offeringId)
        .single();

    return ManagerOfferingModel.fromJson(response);
  }

  @override
  Future<List<ManagerAmenity>> fetchAmenities() async {
    final response = await _supabase
        .from("amenities")
        .select();

    return response.map((e) => ManagerAmenityModel.fromJson(e)).toList();
  }
  
  @override
  Future<List<ManagerRoomModel>> fetchRooms(String hotelId, {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'room_number', 'capacity', 'created_at', 'is_active'};
    final sortBy = allowedSort.contains(normalized['sort_by']) ? normalized['sort_by'] as String : 'room_number';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isActive = normalized['is_active'] as bool?;

    dynamic query = _supabase
        .from('hotel_rooms')
        .select()
        .eq('hotel_id', hotelId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    query = query.order(sortBy, ascending: sortAsc);

    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
        // .filter(filters);

    return response.map((e) => ManagerRoomModel.fromJson(e)).toList();
  }
  
  @override
  Future<List<StaffMember>> fetchStaff(String hotelId) {
    // TODO: implement fetchStaff
    throw UnimplementedError();
  }
  
  @override
  Future<RoomAvailability> getRoomAvailability(String roomId, DateTime startDate, DateTime endDate) {
    // TODO: implement getRoomAvailability
    throw UnimplementedError();
  }
  
  @override
  Future<ManagerRoomModel> getRoomById(String roomId) async {
    final response = await _supabase
        .from('hotel_rooms')
        .select()
        .eq('id', roomId);

    return ManagerRoomModel.fromJson(response.first);
  }
  
  @override
  Future<List<ManagerRoomModel>> getRoomsByOffering(String offeringId) {
    // TODO: implement getRoomsByOffering
    throw UnimplementedError();
  }
  
  @override
  Future<void> inviteStaff(String hotelId, String email, String role) {
    // TODO: implement inviteStaff
    throw UnimplementedError();
  }
  
  @override
  Future<ManagerOfferingModel> updateOffering(ManagerOffering offering) {
    final res = _supabase.from('offerings')
        .update(ManagerOfferingModel.fromEntity(offering).toJson())
        .eq('id', offering.id as Object)
        .select()
        .single();
    return res.then((value) => ManagerOfferingModel.fromJson(value));
  }
  
  @override
  Future<ManagerRoomModel> updateRoom(ManagerRoom room) {
    final res = _supabase.from('hotel_rooms')
        .update(ManagerRoomModel.fromEntity(room).toJson())
        .eq('id', room.id as Object)
        .select()
        .single();
    return res.then((value) => ManagerRoomModel.fromJson(value));
  }
  
  @override
  Future<void> updateRoomStatus(RoomStatus statusData) async {
    // Convert dates to ISO strings (yyyy-mm-dd )
    List<String>? dates;
    if (statusData.dates != null && statusData.dates!.isNotEmpty) {
      dates = statusData.dates!
          .map((d) => d.toIso8601String().split('T').first)
          .toList();
    }

    final params = {
      'p_room_id': statusData.roomId,
      'p_status': statusData.status.name,
      'p_note': statusData.note,
      'p_start_date': statusData.startDate?.toIso8601String().split('T').first,
      'p_end_date': statusData.endDate?.toIso8601String().split('T').first,
      'p_dates': dates,
    };

    final response = await _supabase.rpc('upsert_room_statuses', params: params);

    if (response.error != null) {
      throw Exception('Failed to upsert room status: ${response.error!.message}');
    }
  }

  @override
  Future<List<ManagerBookingItem>> fetchBookingItems(String hotelId, {required Map<String, dynamic> filters}) async {
    final limit = filters['limit'] as int?;
    final offset = (filters['offset'] as int?) ?? 0;
    const allowedSort = {'start_date', 'end_date', 'created_at', 'id'};
    final sortBy = allowedSort.contains(filters['sort_by']) ? filters['sort_by'] as String : 'start_date';
    final sortAsc = filters['sort_asc'] as bool? ?? false;
    final status = filters['status'] as String?;
    dynamic query = _supabase
        .from('booking_items')
        .select()
        .eq('hotel_id', hotelId);

    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status.trim());
    }
    query = query.order(sortBy, ascending: sortAsc).order('id', ascending: false);

    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    return await query.then(
      (value) =>
          value.map((booking) => ManagerBookingItemModel.fromJson(booking)).toList(),
    );
  }

  @override
  Future<ManagerHotel> fetchHotelDetail(String hotelId) async {
    return await _supabase
        .from('hotels')
        .select()
        .eq('id', hotelId)
        .single()
        .then((value) => ManagerHotelModel.fromJson(value));
  }

  @override
  Future<ManagerBooking> updateBooking(ManagerBooking booking) {
    // TODO: implement updateBooking
    throw UnimplementedError();
  }
  
  @override
  Future<List<ManagerBookingItem>> fetchBookingsForRoom(String roomId) {
    return _supabase
        .from('booking_items')
        .select()
        .eq('room_id', roomId)
        .order('start_date', ascending: false)
        .order('id', ascending: false)
        .then((value) => value.map((booking) => ManagerBookingItemModel.fromJson(booking)).toList());
  }

  @override
  Future<List<ManagerPaymentModel>> fetchPayments(String hotelId, {Map<String, dynamic>? filters}) async{
      final normalized = filters ?? const <String, dynamic>{};
      final limit = normalized['limit'] as int?;
      final offset = (normalized['offset'] as int?) ?? 0;
      const allowedSort = {'settled_at', 'settled_amount', 'customer_name'};
      final sortBy = allowedSort.contains(normalized['sort_by']) ? normalized['sort_by'] as String : 'settled_at';
      final sortAsc = normalized['sort_asc'] as bool? ?? false;
      final settlementStatus = normalized['settlement_status'] as String?;

      // Supabase treats the view just like a table for SELECT queries.
      dynamic query = _supabase
          .from('manager_hotel_payments_view')
          .select()
          .eq('hotel_id', hotelId); // Filter by the hotel_id column

      if (settlementStatus != null && settlementStatus.trim().isNotEmpty) {
        query = query.eq('settlement_status', settlementStatus.trim());
      }
      query = query.order(sortBy, ascending: sortAsc);
      if (limit != null && limit > 0) {
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;

      return response.map((json) => ManagerPaymentModel.fromJson(json)).toList();
      
  }
}
