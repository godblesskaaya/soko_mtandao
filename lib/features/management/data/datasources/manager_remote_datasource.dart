// supabase implementation of manager datasource
import 'package:soko_mtandao/features/management/data/models/manager_amenity_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_item_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_hotel_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_offering_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_payment_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_wallet_summary_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_room_model.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/features/hotel_detail/data/models/room_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_wallet_summary.dart';
import 'package:soko_mtandao/features/management/domain/entities/staff_member.dart';
import 'manager_datasource.dart';

class ManagerRemoteDataSource implements ManagerDataSource {
  final SupabaseClient _supabase = Supabase.instance.client;

  ManagerRemoteDataSource();

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

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> value) {
    return Map<String, dynamic>.fromEntries(
      value.entries.where((entry) => entry.value != null),
    );
  }

  List<String> _amenityIdsForHotel(ManagerHotel hotel) {
    return hotel.amenities
        .map((amenity) => amenity.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Map<String, dynamic> _hotelRpcParams(
    ManagerHotel hotel, {
    required String? hotelId,
  }) {
    return {
      'p_hotel_id': hotelId?.trim().isEmpty == true ? null : hotelId,
      'p_name': hotel.name.trim(),
      'p_address': hotel.address.trim(),
      'p_description': hotel.description.trim(),
      'p_images': hotel.images,
      'p_amenity_ids': _amenityIdsForHotel(hotel),
      'p_lat': hotel.lat,
      'p_lng': hotel.lng,
      'p_total_rooms': hotel.totalRooms,
      'p_region': hotel.region.trim(),
      'p_country': hotel.country.trim(),
      'p_city': hotel.city.trim(),
      'p_phone_number': hotel.phoneNumber.trim(),
      'p_email': hotel.email.trim(),
      'p_website': hotel.website?.trim(),
      'p_check_in_from': hotel.checkInFrom?.trim(),
      'p_check_in_until': hotel.checkInUntil?.trim(),
      'p_check_out_until': hotel.checkOutUntil?.trim(),
      'p_stay_rules': hotel.stayRules,
      'p_check_in_requirements': hotel.checkInRequirements,
      'p_is_active': hotel.isActive,
    };
  }

  String _roomStatusToDatabase(RoomStatusType status) {
    switch (status) {
      case RoomStatusType.vacant:
        return 'available';
      case RoomStatusType.outOfService:
        return 'not_available';
      case RoomStatusType.pending:
        return 'pending';
      case RoomStatusType.booked:
        return 'booked';
    }
  }

  RoomStatusType _roomStatusTypeFromDatabase(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'booked':
        return RoomStatusType.booked;
      case 'pending':
        return RoomStatusType.pending;
      case 'not_available':
      case 'out_of_service':
        return RoomStatusType.outOfService;
      case 'available':
      default:
        return RoomStatusType.vacant;
    }
  }

  @override
  Future<List<ManagerHotelModel>> fetchManagedHotels(String managerUserId,
      {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'name', 'created_at', 'rating', 'city'};
    final sortBy = allowedSort.contains(normalized['sort_by'])
        ? normalized['sort_by'] as String
        : 'name';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isActive = normalized['is_active'] as bool?;

    dynamic query =
        _supabase.from('hotels').select().eq('manager_user_id', managerUserId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    final rows = List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return rows.map(ManagerHotelModel.fromJson).toList(growable: false);
  }

  @override
  Future<ManagerHotelModel> createHotel(ManagerHotel hotel) async {
    final hotelId = await _supabase.rpc(
      'upsert_managed_hotel',
      params: _hotelRpcParams(hotel, hotelId: null),
    );
    return ManagerHotelModel.fromEntity(
      await fetchHotelDetail(hotelId.toString()),
    );
  }

  @override
  Future<ManagerHotelModel> updateHotel(ManagerHotel hotel) async {
    final hotelId = await _supabase.rpc(
      'upsert_managed_hotel',
      params: _hotelRpcParams(hotel, hotelId: hotel.id),
    );
    return ManagerHotelModel.fromEntity(
      await fetchHotelDetail(hotelId.toString()),
    );
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _supabase.rpc('cancel_booking_for_manager', params: {
      'p_booking_id': bookingId,
      'p_reason': 'Manager cancellation requested from app',
    });
  }

  @override
  Future<void> changeStaffRole(String staffId, String role) async {
    await _supabase.rpc('update_staff_assignment', params: {
      'p_staff_id': staffId,
      'p_role': role.trim(),
      'p_is_active': null,
    });
  }

  @override
  Future<ManagerOfferingModel> createOffering(ManagerOffering offering) async {
    final offeringId = await _supabase.rpc(
      'upsert_offering_with_amenities',
      params: {
        'p_offering_id': null,
        'p_hotel_id': offering.hotelId,
        'p_title': offering.title.trim(),
        'p_description': offering.description.trim(),
        'p_price': offering.basePrice,
        'p_max_guests': offering.maxGuests,
        'p_is_available': offering.isActive,
        'p_amenity_ids': offering.amenityIds,
        'p_images': offering.imageUrls,
      },
    );
    final hydrated = await fetchOfferingById(offeringId.toString());
    return ManagerOfferingModel.fromEntity(hydrated);
  }

  @override
  Future<ManagerRoomModel> createRoom(ManagerRoom room) async {
    final roomId = await _supabase.rpc('upsert_room_for_manager', params: {
      'p_room_id': null,
      'p_hotel_id': room.hotelId,
      'p_offering_id': room.offeringId,
      'p_room_number': room.roomNumber.trim(),
      'p_capacity': room.capacity,
      'p_is_active': room.isActive,
    });
    return getRoomById(roomId.toString());
  }

  @override
  Future<void> deactivateHotel(String hotelId) async {
    await _supabase.rpc('deactivate_hotel_for_manager', params: {
      'p_hotel_id': hotelId,
      'p_reason': 'Deactivated from manager app',
    });
  }

  @override
  Future<void> deleteOffering(String offeringId) async {
    await _supabase.rpc('archive_offering_for_manager', params: {
      'p_offering_id': offeringId,
      'p_reason': 'Archived from manager app',
    });
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    await _supabase.rpc('archive_room_for_manager', params: {
      'p_room_id': roomId,
      'p_reason': 'Archived from manager app',
    });
  }

  @override
  Future<ManagerBookingModel> fetchBookingDetail(String bookingId) async {
    final response =
        await _supabase.from('bookings').select().eq('id', bookingId);

    return ManagerBookingModel.fromJson(response.first);
  }

  @override
  Future<List<ManagerBookingItemModel>> fetchBookings(String hotelId,
      {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'start_date', 'end_date', 'created_at', 'id'};
    final sortBy = allowedSort.contains(normalized['sort_by'])
        ? normalized['sort_by'] as String
        : 'start_date';
    final sortAsc = normalized['sort_asc'] as bool? ?? false;

    dynamic query =
        _supabase.from('booking_items').select().eq('hotel_id', hotelId);
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    return _castRows(response)
        .map(ManagerBookingItemModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<ManagerOfferingModel>> fetchOfferings(String hotelId,
      {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {
      'title',
      'price',
      'max_guests',
      'created_at',
      'is_available'
    };
    final sortBy = allowedSort.contains(normalized['sort_by'])
        ? normalized['sort_by'] as String
        : 'title';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isAvailable = normalized['is_available'] as bool?;

    dynamic query =
        _supabase.from('offerings').select().eq('hotel_id', hotelId);

    if (isAvailable != null) {
      query = query.eq('is_available', isAvailable);
    }
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    final rows = _castRows(response);
    if (rows.isEmpty) return const <ManagerOfferingModel>[];

    final offeringIds = rows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    final amenityIdMap = <String, List<String>>{};
    if (offeringIds.isNotEmpty) {
      final amenityRows = await _supabase
          .from('offering_amenities')
          .select('offering_id, amenity_id')
          .inFilter('offering_id', offeringIds);
      for (final row in _castRows(amenityRows)) {
        final offeringId = (row['offering_id'] ?? '').toString();
        final amenityId = (row['amenity_id'] ?? '').toString();
        if (offeringId.isEmpty || amenityId.isEmpty) continue;
        final bucket = amenityIdMap.putIfAbsent(offeringId, () => <String>[]);
        bucket.add(amenityId);
      }
    }

    return rows.map((row) {
      final id = (row['id'] ?? '').toString();
      final enriched = Map<String, dynamic>.from(row)
        ..['amenity_ids'] = amenityIdMap[id] ?? const <String>[];
      return ManagerOfferingModel.fromJson(enriched);
    }).toList(growable: false);
  }

  @override
  Future<ManagerOffering> fetchOfferingById(String offeringId) async {
    final response = await _supabase
        .from('offerings')
        .select()
        .eq('id', offeringId)
        .single();
    final amenityRows = await _supabase
        .from('offering_amenities')
        .select('amenity_id')
        .eq('offering_id', offeringId);
    final amenityIds = _castRows(amenityRows)
        .map((row) => (row['amenity_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final enriched = Map<String, dynamic>.from(response as Map)
      ..['amenity_ids'] = amenityIds;
    return ManagerOfferingModel.fromJson(enriched);
  }

  @override
  Future<List<ManagerAmenity>> fetchAmenities() async {
    final response = await _supabase.from("amenities").select();
    final rows = _castRows(response);
    return rows.map(ManagerAmenityModel.fromJson).toList(growable: false);
  }

  @override
  Future<List<ManagerRoomModel>> fetchRooms(String hotelId,
      {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'room_number', 'capacity', 'created_at', 'is_active'};
    final sortBy = allowedSort.contains(normalized['sort_by'])
        ? normalized['sort_by'] as String
        : 'room_number';
    final sortAsc = normalized['sort_asc'] as bool? ?? true;
    final isActive = normalized['is_active'] as bool?;

    dynamic query =
        _supabase.from('hotel_rooms').select().eq('hotel_id', hotelId);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    query = query.order(sortBy, ascending: sortAsc);

    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    final rows = _castRows(response);
    return rows.map(ManagerRoomModel.fromJson).toList(growable: false);
  }

  @override
  Future<List<StaffMember>> fetchStaff(String hotelId) async {
    final response = await _supabase
        .from('staff')
        .select('id,name,email,phone,role,is_active')
        .eq('hotel_id', hotelId)
        .order('created_at', ascending: false);
    final rows = _castRows(response);
    return rows
        .map(
          (row) => StaffMember(
            id: (row['id'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            email: (row['email'] ?? '').toString(),
            phone: (row['phone'] ?? '').toString(),
            role: (row['role'] ?? '').toString(),
            isActive: row['is_active'] != false,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RoomAvailability> getRoomAvailability(
      String roomId, DateTime startDate, DateTime endDate) async {
    final roomRow =
        await _supabase.from('hotel_rooms').select().eq('id', roomId).single();
    final statusRows = await _supabase
        .from('room_statuses')
        .select('date,status')
        .eq('room_id', roomId)
        .gte('date', startDate.toIso8601String().split('T').first)
        .lte('date', endDate.toIso8601String().split('T').first);

    final availability = <DateTime, RoomStatusType>{};
    for (final row in _castRows(statusRows)) {
      final rawDate = row['date'];
      if (rawDate == null) continue;
      availability[DateTime.parse(rawDate.toString())] =
          _roomStatusTypeFromDatabase(row['status']);
    }

    return RoomAvailability(
      room: RoomModel.fromJson(Map<String, dynamic>.from(roomRow as Map)),
      availabilityByDate: availability,
    );
  }

  @override
  Future<ManagerRoomModel> getRoomById(String roomId) async {
    final response =
        await _supabase.from('hotel_rooms').select().eq('id', roomId);

    return ManagerRoomModel.fromJson(response.first);
  }

  @override
  Future<List<ManagerRoomModel>> getRoomsByOffering(String offeringId) async {
    final response = await _supabase
        .from('hotel_rooms')
        .select()
        .eq('offering_id', offeringId)
        .order('room_number', ascending: true);
    return _castRows(response)
        .map(ManagerRoomModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> inviteStaff(String hotelId, String email, String role) async {
    await _supabase.rpc('create_staff_invite', params: {
      'p_hotel_id': hotelId,
      'p_email': email.trim(),
      'p_staff_title': role.trim(),
    });
  }

  @override
  Future<ManagerOfferingModel> updateOffering(ManagerOffering offering) {
    final offeringId = (offering.id ?? '').trim();
    if (offeringId.isEmpty) {
      throw ArgumentError('offering.id is required when updating an offering');
    }
    return _supabase.rpc('upsert_offering_with_amenities', params: {
      'p_offering_id': offeringId,
      'p_hotel_id': offering.hotelId,
      'p_title': offering.title.trim(),
      'p_description': offering.description.trim(),
      'p_price': offering.basePrice,
      'p_max_guests': offering.maxGuests,
      'p_is_available': offering.isActive,
      'p_amenity_ids': offering.amenityIds,
      'p_images': offering.imageUrls,
    }).then((value) async {
      final hydrated = await fetchOfferingById(offeringId);
      return ManagerOfferingModel.fromEntity(hydrated);
    });
  }

  @override
  Future<ManagerRoomModel> updateRoom(ManagerRoom room) {
    return _supabase.rpc('upsert_room_for_manager', params: {
      'p_room_id': room.id,
      'p_hotel_id': room.hotelId,
      'p_offering_id': room.offeringId,
      'p_room_number': room.roomNumber.trim(),
      'p_capacity': room.capacity,
      'p_is_active': room.isActive,
    }).then((value) => getRoomById(value.toString()));
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
      'p_status': _roomStatusToDatabase(statusData.status),
      'p_note': statusData.note,
      'p_start_date': statusData.startDate?.toIso8601String().split('T').first,
      'p_end_date': statusData.endDate?.toIso8601String().split('T').first,
      'p_dates': dates,
    };

    await _supabase.rpc('upsert_room_statuses', params: params);
  }

  @override
  Future<List<ManagerBookingItem>> fetchBookingItems(String hotelId,
      {required Map<String, dynamic> filters}) async {
    final limit = filters['limit'] as int?;
    final offset = (filters['offset'] as int?) ?? 0;
    const allowedSort = {'start_date', 'end_date', 'created_at', 'id'};
    final sortBy = allowedSort.contains(filters['sort_by'])
        ? filters['sort_by'] as String
        : 'start_date';
    final sortAsc = filters['sort_asc'] as bool? ?? false;
    final status = filters['status'] as String?;
    dynamic query =
        _supabase.from('booking_items').select().eq('hotel_id', hotelId);

    if (status != null && status.trim().isNotEmpty) {
      query = query.eq('status', status.trim());
    }
    query =
        query.order(sortBy, ascending: sortAsc).order('id', ascending: false);

    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    final rows = _castRows(response);
    return rows.map(ManagerBookingItemModel.fromJson).toList(growable: false);
  }

  @override
  Future<ManagerHotel> fetchHotelDetail(String hotelId) async {
    final hotelRow =
        await _supabase.from('hotels').select().eq('id', hotelId).single();
    final amenityRows = await _supabase
        .from('hotel_amenities')
        .select('amenities:amenity_id(amenity_id,name,icon_url)')
        .eq('hotel_id', hotelId);
    final amenities = _castRows(amenityRows)
        .map(_extractAmenityMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final enriched = Map<String, dynamic>.from(hotelRow as Map)
      ..['amenities'] = amenities;
    return ManagerHotelModel.fromJson(enriched);
  }

  @override
  Future<ManagerBooking> updateBooking(ManagerBooking booking) async {
    final response = await _supabase
        .from('bookings')
        .update(_withoutNulls(ManagerBookingModel.fromEntity(booking).toJson())
          ..remove('id')
          ..remove('created_at'))
        .eq('id', booking.id)
        .select()
        .single();
    return ManagerBookingModel.fromJson(response);
  }

  @override
  Future<List<ManagerBookingItem>> fetchBookingsForRoom(String roomId) {
    return _supabase
        .from('booking_items')
        .select()
        .eq('room_id', roomId)
        .order('start_date', ascending: false)
        .order('id', ascending: false)
        .then((value) => _castRows(value)
            .map(ManagerBookingItemModel.fromJson)
            .toList(growable: false));
  }

  @override
  Future<List<ManagerPaymentModel>> fetchPayments(String hotelId,
      {Map<String, dynamic>? filters}) async {
    final normalized = filters ?? const <String, dynamic>{};
    final limit = normalized['limit'] as int?;
    final offset = (normalized['offset'] as int?) ?? 0;
    const allowedSort = {'settled_at', 'settled_amount', 'customer_name'};
    final sortBy = allowedSort.contains(normalized['sort_by'])
        ? normalized['sort_by'] as String
        : 'settled_at';
    final sortAsc = normalized['sort_asc'] as bool? ?? false;
    final settlementStatus = normalized['settlement_status'] as String?;
    final startDate = normalized['start_date'] as DateTime?;
    final endDate = normalized['end_date'] as DateTime?;

    // Supabase treats the view just like a table for SELECT queries.
    dynamic query = _supabase
        .from('manager_hotel_payments_view')
        .select()
        .eq('hotel_id', hotelId); // Filter by the hotel_id column

    if (settlementStatus != null && settlementStatus.trim().isNotEmpty) {
      query = query.eq('settlement_status', settlementStatus.trim());
    }
    if (startDate != null) {
      query = query.gte('settled_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('settled_at', endDate.toIso8601String());
    }
    query = query.order(sortBy, ascending: sortAsc);
    if (limit != null && limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    final rows = _castRows(response);
    return rows.map(ManagerPaymentModel.fromJson).toList(growable: false);
  }

  @override
  Future<ManagerWalletSummary> fetchWalletSummary(String hotelId) async {
    final response = await _supabase
        .from('hotel_financial_summary_view')
        .select()
        .eq('hotel_id', hotelId)
        .maybeSingle();

    if (response == null) {
      return ManagerWalletSummaryModel(
        hotelId: hotelId,
        totalRevenue: 0,
        totalCommissionPaid: 0,
        netEarnings: 0,
        pendingBalance: 0,
        availableBalance: 0,
        lockedBalance: 0,
        paidTotal: 0,
        lifetimeEarnings: 0,
      );
    }

    return ManagerWalletSummaryModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<String?> requestPayout(
    String hotelId, {
    double minimumThreshold = 0,
    String provider = 'azampay_disburse',
  }) async {
    final response = await _supabase.rpc('request_hotel_payout', params: {
      'p_hotel_id': hotelId,
      'p_provider': provider,
      'p_minimum_threshold': minimumThreshold,
      'p_idempotency_key':
          'manual_${hotelId}_${DateTime.now().millisecondsSinceEpoch}',
    });
    if (response == null) return null;
    final batchId = response.toString();

    try {
      await _supabase.functions.invoke(
        'payout_dispatch',
        body: {'payout_batch_id': batchId},
      );
    } catch (_) {
      // Batch was created and locked; dispatch can be retried by scheduler/ops.
    }

    return batchId;
  }

  @override
  Future<User> updateManagerProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? title,
    String? bio,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException('No authenticated user session.');
    }

    final cleanedFirstName = firstName.trim();
    final cleanedLastName = lastName.trim();
    final cleanedPhone = phone.trim();
    final cleanedTitle = title?.trim() ?? '';
    final cleanedBio = bio?.trim() ?? '';
    final fullName = '$cleanedFirstName $cleanedLastName'.trim();

    final metadata = Map<String, dynamic>.from(
      currentUser.userMetadata ?? const <String, dynamic>{},
    );
    metadata['firstName'] = cleanedFirstName;
    metadata['lastName'] = cleanedLastName;
    metadata['fullName'] = fullName;
    metadata['phone'] = cleanedPhone;

    if (cleanedTitle.isEmpty) {
      metadata.remove('managerTitle');
    } else {
      metadata['managerTitle'] = cleanedTitle;
    }

    if (cleanedBio.isEmpty) {
      metadata.remove('bio');
    } else {
      metadata['bio'] = cleanedBio;
    }

    final metadataRes =
        await _supabase.auth.updateUser(UserAttributes(data: metadata));
    final updatedAfterMetadata = metadataRes.user;
    if (updatedAfterMetadata == null) {
      throw Exception('Failed to update profile metadata.');
    }

    User refreshedUser = updatedAfterMetadata;
    if (cleanedPhone.isNotEmpty) {
      try {
        final phoneRes = await _supabase.auth
            .updateUser(UserAttributes(phone: cleanedPhone));
        if (phoneRes.user != null) {
          refreshedUser = phoneRes.user!;
        }
      } catch (_) {
        // Phone update can fail when phone auth is disabled; keep metadata saved.
      }
    }

    try {
      await _supabase
          .from('staff')
          .update({'name': fullName, 'phone': cleanedPhone}).eq(
              'user_id', currentUser.id);
    } catch (_) {
      // Manager profile update should still succeed even if no staff row exists.
    }

    try {
      await _supabase.auth.refreshSession();
    } catch (_) {}

    return refreshedUser;
  }
}
