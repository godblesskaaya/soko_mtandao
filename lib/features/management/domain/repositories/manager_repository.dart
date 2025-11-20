import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';

import '../entities/manager_hotel.dart';
import '../entities/manager_offering.dart';
import '../entities/manager_room.dart';
import '../entities/staff_member.dart';
import '../entities/manager_booking_summary.dart';

abstract class ManagerRepository {
  // Hotels
  Future<List<ManagerHotel>> getManagedHotels(String managerUserId);
  Future<ManagerHotel> getHotelDetail(String hotelId);
  Future<ManagerHotel> createHotel(ManagerHotel hotel);
  Future<ManagerHotel> updateHotel(ManagerHotel hotel);
  Future<void> deactivateHotel(String hotelId);
  Future<List<ManagerAmenity>> getAmenities();

  // Offerings
  Future<List<ManagerOffering>> getOfferings(String hotelId);
  Future<ManagerOffering> createOffering(ManagerOffering offering);
  Future<ManagerOffering> updateOffering(ManagerOffering offering);
  Future<void> deleteOffering(String offeringId);

  // Rooms
  Future<List<ManagerRoom>> getRooms(String hotelId, Map<String, dynamic>? filters);
  Future<ManagerRoom> createRoom(ManagerRoom room);
  Future<ManagerRoom> updateRoom(ManagerRoom room);
  Future<void> updateRoomStatus(RoomStatus status);
  Future<void> deleteRoom(String roomId);
  Future<ManagerRoom> getRoomById(String roomId);
  Future<RoomAvailability> getRoomAvailability(String roomId, DateTime startDate, DateTime endDate);
  Future<List<ManagerRoom>> getRoomsByOffering(String offeringId);
  

  // Bookings
  Future<List<ManagerBookingItem>> getBookings({required String hotelId, Map<String, dynamic>? filters});
  Future<ManagerBooking> getBookingDetail(String bookingId);
  Future<ManagerBooking> updateBooking(ManagerBooking booking);
  Future<void> cancelBooking(String bookingId);

  // Staff
  Future<List<StaffMember>> getStaff(String hotelId);
  Future<void> inviteStaff(String hotelId, String email, String role);
  Future<void> changeStaffRole(String staffId, String role);

  Future<List<ManagerBookingItem>> getBookingItems({required String hotelId, required Map<String, dynamic> filters});

  Future<List<ManagerBookingItem>> getBookingsForRoom({required String roomId});

  Future<ManagerOffering> getOfferingById(String offeringId);
}
