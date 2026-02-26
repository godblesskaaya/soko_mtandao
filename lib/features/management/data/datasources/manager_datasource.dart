import 'package:soko_mtandao/features/management/data/models/manager_booking_item_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_booking_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_hotel_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_offering_model.dart';
import 'package:soko_mtandao/features/management/data/models/manager_room_model.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_wallet_summary.dart';
import 'package:soko_mtandao/features/management/domain/entities/staff_member.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ManagerDataSource {
  Future<List<ManagerHotelModel>> fetchManagedHotels(String managerUserId,
      {Map<String, dynamic>? filters});
  Future<ManagerHotelModel> createHotel(ManagerHotel hotel);
  Future<ManagerHotelModel> updateHotel(ManagerHotel hotel);
  Future<void> deactivateHotel(String hotelId);

  Future<List<ManagerOfferingModel>> fetchOfferings(String hotelId,
      {Map<String, dynamic>? filters});
  Future<ManagerOfferingModel> createOffering(ManagerOffering offering);
  Future<ManagerOfferingModel> updateOffering(ManagerOffering offering);
  Future<void> deleteOffering(String offeringId);

  Future<List<ManagerRoomModel>> fetchRooms(String hotelId,
      {Map<String, dynamic>? filters});
  Future<ManagerRoomModel> createRoom(ManagerRoom room);
  Future<ManagerRoomModel> updateRoom(ManagerRoom room);
  Future<void> updateRoomStatus(RoomStatus status);

  Future<List<ManagerBookingItemModel>> fetchBookings(String hotelId,
      {Map<String, dynamic>? filters});
  Future<ManagerBookingModel> fetchBookingDetail(String bookingId);
  Future<void> cancelBooking(String bookingId);

  Future<List<StaffMember>> fetchStaff(String hotelId);
  Future<void> inviteStaff(String hotelId, String email, String role);
  Future<void> changeStaffRole(String staffId, String role);

  void deleteRoom(String roomId);

  Future<List<ManagerRoomModel>> getRoomsByOffering(String offeringId);

  Future<ManagerRoomModel> getRoomById(String roomId);

  Future<RoomAvailability> getRoomAvailability(
      String roomId, DateTime startDate, DateTime endDate);

  Future<List<ManagerBookingItem>> fetchBookingItems(String hotelId,
      {required Map<String, dynamic> filters});

  Future<ManagerHotel> fetchHotelDetail(String hotelId);

  Future<ManagerBooking> updateBooking(ManagerBooking booking);

  Future<List<ManagerBookingItem>> fetchBookingsForRoom(String roomId);

  Future<ManagerOffering> fetchOfferingById(String offeringId);

  Future<List<ManagerAmenity>> fetchAmenities();

  Future<List<ManagerPayment>> fetchPayments(String hotelId,
      {Map<String, dynamic>? filters});
  Future<ManagerWalletSummary> fetchWalletSummary(String hotelId);
  Future<String?> requestPayout(
    String hotelId, {
    double minimumThreshold = 0,
    String provider = 'azampay_disburse',
  });

  Future<User> updateManagerProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? title,
    String? bio,
  });
}
