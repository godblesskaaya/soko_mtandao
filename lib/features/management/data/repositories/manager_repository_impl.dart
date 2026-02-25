import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_payment.dart';

import '../../domain/repositories/manager_repository.dart';
import '../datasources/manager_datasource.dart';
import '../../domain/entities/manager_hotel.dart';
import '../../domain/entities/manager_offering.dart';
import '../../domain/entities/manager_room.dart';
import '../../domain/entities/staff_member.dart';

class ManagerRepositoryImpl implements ManagerRepository {
  final ManagerDataSource dataSource;
  ManagerRepositoryImpl(this.dataSource);

  @override
  Future<List<ManagerHotel>> getManagedHotels(String managerUserId, {Map<String, dynamic>? filters}) =>
      dataSource.fetchManagedHotels(managerUserId, filters: filters);

  @override
  Future<ManagerHotel> createHotel(ManagerHotel hotel) => dataSource.createHotel(hotel);

  @override
  Future<ManagerHotel> updateHotel(ManagerHotel hotel) => dataSource.updateHotel(hotel);

  @override
  Future<void> deactivateHotel(String hotelId) => dataSource.deactivateHotel(hotelId);

  @override
  Future<List<ManagerOffering>> getOfferings(String hotelId, {Map<String, dynamic>? filters}) =>
      dataSource.fetchOfferings(hotelId, filters: filters);

  @override
  Future<ManagerOffering> createOffering(ManagerOffering offering) => dataSource.createOffering(offering);

  @override
  Future<ManagerOffering> updateOffering(ManagerOffering offering) => dataSource.updateOffering(offering);

  @override
  Future<void> deleteOffering(String offeringId) => dataSource.deleteOffering(offeringId);

  @override
  Future<List<ManagerRoom>> getRooms(String hotelId, Map<String, dynamic>? filters) => dataSource.fetchRooms(hotelId, filters: filters);

  @override
  Future<ManagerRoom> createRoom(ManagerRoom room) => dataSource.createRoom(room);

  @override
  Future<ManagerRoom> updateRoom(ManagerRoom room) => dataSource.updateRoom(room);

  @override
  Future<void> updateRoomStatus(RoomStatus status) => dataSource.updateRoomStatus(status);

  @override
  Future<List<ManagerBookingItem>> getBookings({required String hotelId, Map<String, dynamic>? filters}) => dataSource.fetchBookings(hotelId, filters: filters);

  @override
  Future<ManagerBooking> getBookingDetail(String bookingId) => dataSource.fetchBookingDetail(bookingId);

  @override
  Future<void> cancelBooking(String bookingId) => dataSource.cancelBooking(bookingId);

  @override
  Future<List<StaffMember>> getStaff(String hotelId) => dataSource.fetchStaff(hotelId);

  @override
  Future<void> inviteStaff(String hotelId, String email, String role) => dataSource.inviteStaff(hotelId, email, role);

  @override
  Future<void> changeStaffRole(String staffId, String role) => dataSource.changeStaffRole(staffId, role);

  @override
  Future<void> deleteRoom(String roomId) async {
    return dataSource.deleteRoom(roomId);
  }

  @override
  Future<RoomAvailability> getRoomAvailability(String roomId, DateTime startDate, DateTime endDate) {
    return dataSource.getRoomAvailability(roomId, startDate, endDate);
  }

  @override
  Future<ManagerRoom> getRoomById(String roomId) {
    return dataSource.getRoomById(roomId);
  }

  @override
  Future<List<ManagerRoom>> getRoomsByOffering(String offeringId) {
    return dataSource.getRoomsByOffering(offeringId);
  }

  @override
  Future<List<ManagerBookingItem>> getBookingItems({required String hotelId, required Map<String, dynamic> filters}) {
    return dataSource.fetchBookingItems(hotelId, filters: filters);
  }

  @override
  Future<ManagerHotel> getHotelDetail(String hotelId) {
    return dataSource.fetchHotelDetail(hotelId);
  }

  @override
  Future<ManagerBooking> updateBooking(ManagerBooking booking) {
    return dataSource.updateBooking(booking);
  }
  
  @override
  Future<List<ManagerBookingItem>> getBookingsForRoom({required String roomId}) {
    return dataSource.fetchBookingsForRoom(roomId);
  }
  
  @override
  Future<ManagerOffering> getOfferingById(String offeringId) {
    return dataSource.fetchOfferingById(offeringId);
  }

  @override
  Future<List<ManagerAmenity>> getAmenities() {
    return dataSource.fetchAmenities();
  }

  @override
  Future<List<ManagerPayment>> getPayments(String hotelId, {Map<String, dynamic>? filters}) {
    return dataSource.fetchPayments(hotelId, filters: filters);
  }
}
