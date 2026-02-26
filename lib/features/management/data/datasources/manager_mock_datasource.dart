// import 'dart:async';
// import 'package:soko_mtandao/core/config/app_config.dart';
// import 'package:soko_mtandao/features/hotel_detail/domain/entities/room.dart';
// import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_availability.dart';
// import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
// import 'package:soko_mtandao/features/management/data/models/manager_offering_model.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_booking_item.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_booking_summary.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
// import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
// import 'package:soko_mtandao/features/management/domain/entities/staff_member.dart';
// import 'manager_datasource.dart';

// class ManagerMockDataSource implements ManagerDataSource {
//   final MockState mockState;
//   ManagerMockDataSource({this.mockState = MockState.success});

//   // small in-memory store
//   final List<ManagerHotel> _hotels = [
//     ManagerHotel(id: 'm_h1', name: 'Demo Hotel A', address: '1 Main St', description: 'Demo hotel', images: [], amenities: [], isActive: true, lat: '', lng: '', rating: 3.4, totalRooms: 30, region: '', country: '', city: '', phoneNumber: '', email: ''),
//     ManagerHotel(id: 'm_h2', name: 'Demo Hotel B', address: '2 Market Rd', description: 'Another hotel', images: [], amenities: [], isActive: true, lat: '', lng: '', rating: 4.5, totalRooms: 23, region: '', country: '', city: '', phoneNumber: '', email: ''),
//   ];

//   final List<ManagerOffering> _offerings = [
//     ManagerOffering(id: 'of1', hotelId: 'm_h1', title: 'Standard', description: 'Standard room', basePrice: 80.0, maxGuests: 2),
//     ManagerOffering(id: 'of2', hotelId: 'm_h1', title: 'Deluxe', description: 'Deluxe room', basePrice: 140.0, maxGuests: 3),
//   ];

//   final List<ManagerRoom> _rooms = [
//     ManagerRoom(id: 'r1', hotelId: 'm_h1', offeringId: 'of1', roomNumber: '101', capacity: 2),
//     ManagerRoom(id: 'r2', hotelId: 'm_h1', offeringId: 'of1', roomNumber: '102', capacity: 2),
//     ManagerRoom(id: 'r3', hotelId: 'm_h1', offeringId: 'of2', roomNumber: '201', capacity: 3),
//   ];

//   final List<ManagerBookingSummary> _bookings = [
//     ManagerBookingSummary(
//       id: 'b1', hotelId: 'm_h1', offeringTitle: 'Standard', roomNumber: '101',
//       startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 2)),
//       guestName: 'Alice', status: 'confirmed', totalPrice: 160.0
//     )
//   ];

//   final List<StaffMember> _staff = [
//     StaffMember(id: 's1', name: 'Sam Manager', email: 'sam@hotel.com', phone: '0700000', role: 'manager'),
//   ];

//   Future<void> _maybeDelay() async {
//     if (mockState == MockState.loading) {
//       await Future.delayed(const Duration(seconds: 1));
//     }
//     if (mockState == MockState.error) {
//       throw Exception('Mock error');
//     }
//   }

//   @override
//   Future<List<ManagerHotel>> fetchManagedHotels(String managerUserId) async {
//     await _maybeDelay();
//     // ignore managerUserId in mock for simplicity
//     return List.from(_hotels);
//   }

//   @override
//   Future<ManagerHotel> createHotel(ManagerHotel hotel) async {
//     await _maybeDelay();
//     final created = ManagerHotel(
//       id: 'm_h${_hotels.length + 1}', name: hotel.name,
//       address: hotel.address, description: hotel.description,
//       images: hotel.images, amenities: hotel.amenities, lat: '', lng: '', rating: null, totalRooms: null, region: '', country: '', city: '', phoneNumber: '', email: '');
//     _hotels.add(created);
//     return created;
//   }

//   @override
//   Future<ManagerHotel> updateHotel(ManagerHotel hotel) async {
//     await _maybeDelay();
//     final idx = _hotels.indexWhere((h) => h.id == hotel.id);
//     if (idx == -1) throw Exception('Hotel not found');
//     _hotels[idx] = hotel;
//     return hotel;
//   }

//   @override
//   Future<void> deactivateHotel(String hotelId) async {
//     await _maybeDelay();
//     final idx = _hotels.indexWhere((h) => h.id == hotelId);
//     if (idx == -1) throw Exception('Hotel not found');
//     _hotels[idx] = ManagerHotel(
//       id: _hotels[idx].id,
//       name: _hotels[idx].name,
//       address: _hotels[idx].address,
//       description: _hotels[idx].description,
//       images: _hotels[idx].images,
//       amenities: _hotels[idx].amenities,
//       isActive: false,
//     );
//   }

//   @override
//   Future<List<ManagerOffering>> fetchOfferings(String hotelId) async {
//     await _maybeDelay();
//     return _offerings.where((o) => o.hotelId == hotelId).toList();
//   }

//   @override
//   Future<ManagerOffering> createOffering(ManagerOffering offering) async {
//     await _maybeDelay();
//     final created = ManagerOffering(
//       id: 'of${_offerings.length + 1}',
//       hotelId: offering.hotelId,
//       title: offering.title,
//       description: offering.description,
//       basePrice: offering.basePrice,
//       maxGuests: offering.maxGuests,
//     );
//     _offerings.add(created);
//     return created;
//   }

//   @override
//   Future<ManagerOfferingModel> updateOffering(ManagerOffering offering) async {
//     await _maybeDelay();
//     final idx = _offerings.indexWhere((o) => o.id == offering.id);
//     if (idx == -1) throw Exception('Offering not found');
//     _offerings[idx] = offering;
//     return ManagerOfferingModel.fromJson({
//       'id': offering.id,
//       'hotelId': offering.hotelId,
//       'title': offering.title,
//       'description': offering.description,
//       'basePrice': offering.basePrice,
//       'maxGuests': offering.maxGuests,
//       'isActive': offering.isActive,
//     });
//   }

//   @override
//   Future<void> deleteOffering(String offeringId) async {
//     await _maybeDelay();
//     // check bookings for offering; if found throw
//     final hasActive = _bookings.any((b) => b.offeringTitle == offeringId);
//     if (hasActive) throw Exception('Cannot delete offering with active bookings');
//     _offerings.removeWhere((o) => o.id == offeringId);
//   }

//   @override
//   Future<List<ManagerRoom>> fetchRooms(String offeringId, {Map<String, dynamic>? filters}) async {
//     await _maybeDelay();
//     // Apply filters if provided
//     var filteredRooms = _rooms.where((r) => r.offeringId == offeringId);
//     if (filters != null) {
//       filters.forEach((key, value) {
//         // filter logic here, return a subset of rooms based on key/value
//         if (key == 'capacity') {
//           filteredRooms = filteredRooms.where((r) => r.capacity == value);
//         }
//       });
//     }
//     return filteredRooms.toList();
//   }

//   @override
//   Future<ManagerRoom> createRoom(ManagerRoom room) async {
//     await _maybeDelay();
//     final created = ManagerRoom(
//       id: 'rm${_rooms.length + 1}',
//       hotelId: room.hotelId,
//       offeringId: room.offeringId,
//       roomNumber: room.roomNumber,
//       capacity: room.capacity,
//     );
//     _rooms.add(created);
//     return created;
//   }

//   @override
//   Future<ManagerRoom> updateRoom(ManagerRoom room) async {
//     await _maybeDelay();
//     final idx = _rooms.indexWhere((r) => r.id == room.id);
//     if (idx == -1) throw Exception('Room not found');
//     _rooms[idx] = room;
//     return room;
//   }

//   @override
//   Future<void> updateRoomStatus(String roomId, DateTime date, String status) async {
//     await _maybeDelay();
//     // mock: do nothing but succeed
//   }

//   @override
//   Future<List<ManagerBookingSummary>> fetchBookings(String hotelId, {Map<String, dynamic>? filters}) async {
//     await _maybeDelay();
//     return _bookings.where((b) => b.hotelId == hotelId).toList();
//   }

//   @override
//   Future<ManagerBookingSummary> fetchBookingDetail(String bookingId) async {
//     await _maybeDelay();
//     final b = _bookings.firstWhere((bk) => bk.id == bookingId, orElse: () => throw Exception('Booking not found'));
//     return b;
//   }

//   @override
//   Future<void> cancelBooking(String bookingId) async {
//     await _maybeDelay();
//     final idx = _bookings.indexWhere((b) => b.id == bookingId);
//     if (idx == -1) throw Exception('Booking not found');
//     _bookings[idx] = ManagerBookingSummary(
//       id: _bookings[idx].id,
//       hotelId: _bookings[idx].hotelId,
//       offeringTitle: _bookings[idx].offeringTitle,
//       roomNumber: _bookings[idx].roomNumber,
//       startDate: _bookings[idx].startDate,
//       endDate: _bookings[idx].endDate,
//       guestName: _bookings[idx].guestName,
//       status: 'cancelled',
//       totalPrice: _bookings[idx].totalPrice,
//     );
//   }

//   @override
//   Future<List<StaffMember>> fetchStaff(String hotelId) async {
//     await _maybeDelay();
//     return _staff;
//   }

//   @override
//   Future<void> inviteStaff(String hotelId, String email, String role) async {
//     await _maybeDelay();
//     // mock: add staff
//     _staff.add(StaffMember(id: 's${_staff.length + 1}', name: 'Invited', email: email, phone: '', role: role));
//   }

//   @override
//   Future<void> changeStaffRole(String staffId, String role) async {
//     await _maybeDelay();
//     final idx = _staff.indexWhere((s) => s.id == staffId);
//     if (idx == -1) throw Exception('Staff not found');
//     _staff[idx] = StaffMember(id: _staff[idx].id, name: _staff[idx].name, email: _staff[idx].email, phone: _staff[idx].phone, role: role, isActive: _staff[idx].isActive);
//   }

//   @override
//   void deleteRoom(String roomId) {
//     _rooms.removeWhere((r) => r.id == roomId);
//   }

//   @override
//   Future<RoomAvailability> getRoomAvailability(String roomId, DateTime startDate, DateTime endDate) {
//     ManagerRoom managerRoom = _rooms.firstWhere((r) => r.id == roomId, orElse: () => throw Exception('Room not found'));
//     Room room = Room(
//       id: managerRoom.id,
//       offeringId: managerRoom.offeringId,
//       number: managerRoom.roomNumber,
//     );
//     // return mock availability data as a map of date strings to status
//     return Future.value(RoomAvailability(room: room,
//     availabilityByDate: {
//       DateTime(2023, 10, 1): RoomStatusType.vacant,
//       DateTime(2023, 10, 2): RoomStatusType.booked,
//       DateTime(2023, 10, 3): RoomStatusType.pending,
//     },
//     availability: {}));
//   }

//   @override
//   Future<ManagerRoom> getRoomById(String roomId) {
//     return Future.value(_rooms.firstWhere((r) => r.id == roomId));
//   }

//   @override
//   Future<List<ManagerRoom>> getRoomsByOffering(String offeringId) {
//     return Future.value(_rooms.where((r) => r.offeringId == offeringId).toList());
//   }

//   @override
//   Future<List<ManagerBookingItem>> fetchBookingItems(String hotelId, {required Map<String, dynamic> filters}) {
//     // TODO: implement fetchBookingItems
//     throw UnimplementedError();
//   }

//   @override
//   Future<ManagerHotel> fetchHotelDetail(String hotelId) {
//     // TODO: implement fetchHotelDetail
//     throw UnimplementedError();
//   }

//   @override
//   Future<ManagerBooking> updateBooking(ManagerBooking booking) {
//     // TODO: implement updateBooking
//     throw UnimplementedError();
//   }
// }
