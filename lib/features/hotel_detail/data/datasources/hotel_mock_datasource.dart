// datasources/hotel_mock_datasource.dart
import 'dart:async';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/features/hotel_detail/data/datasources/hotel_remote_datasource.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';

import '../models/hotel_model.dart';
import '../models/offering_model.dart';
import '../models/room_model.dart';
import '../../domain/entities/room.dart';

// enum MockState { loading, success, error }

class HotelMockDataSource implements HotelDetailDataSource {
  // MockState mockState = MockState.success;
  final MockState mockState;
  HotelMockDataSource({this.mockState = MockState.success});

  @override
  Future<HotelModel> fetchHotelDetail(String hotelId) async {
    if (mockState == MockState.loading) return Future.delayed(Duration(seconds: 2), () => throw "Loading");
    if (mockState == MockState.error) throw Exception("Failed to fetch hotel");

    List<HotelModel> hotels = [
      HotelModel(
        id: "h1",
        name: "Mock Hotel",
        description: "A cozy place with mock data.",
        address: "123 Mock Street",
        rating: 4.5,
      images: ["https://picsum.photos/800/400", "https://picsum.photos/801/400"],
      amenities: [
        Amenity(id: "a1", name: "Free WiFi", icon: "wifi"),
        Amenity(id: "a2", name: "Swimming Pool", icon: "pool"),
        Amenity(id: "a3", name: "Gym", icon: "fitness_center"),
        Amenity(id: "a4", name: "Restaurant", icon: "restaurant"),
      ],
    ),
    HotelModel(
        id: "h2",
        name: "Another Mock Hotel",
        description: "Another cozy place with mock data.",
        address: "456 Mock Avenue",
        rating: 4.0,
      images: ["https://picsum.photos/800/400", "https://picsum.photos/801/400"],
      amenities: [
        Amenity(id: "a1", name: "Free WiFi", icon: "wifi"),
        Amenity(id: "a2", name: "Swimming Pool", icon: "pool"),
      ],
    ),
    ];

    return hotels.firstWhere((h) => h.id == hotelId, orElse: () => hotels[0]);
  }

  @override
  Future<List<OfferingModel>> fetchHotelOfferings(String hotelId) async {
    if (mockState == MockState.error) throw Exception("Offerings fetch error");
    return [
      OfferingModel(
        id: "o1",
        title: "Deluxe Room",
        description: "Spacious and modern",
        pricePerNight: 120.0,
        maxGuests: 2,
        amenities: [],
        images: ["https://picsum.photos/802/400", "https://picsum.photos/803/400", "https://picsum.photos/804/400"],
      ),
            OfferingModel(
        id: "o3",
        title: "Suite Room",
        description: "Luxurious suite with stunning views",
        pricePerNight: 200.0,
        maxGuests: 4,
        amenities: [],
        images: ["https://picsum.photos/802/400", "https://picsum.photos/803/400", "https://picsum.photos/804/400"],
      ),
      OfferingModel(
        id: "o2",
        title: "Standard Room",
        description: "Comfortable and affordable",
        pricePerNight: 80.0,
        maxGuests: 2,
        amenities: [],
        images: ["https://picsum.photos/802/400", "https://picsum.photos/803/400", "https://picsum.photos/804/400"],
      ),
    ];
  }

  @override
  Future<List<RoomModel>> fetchRoomAvailability(String hotelId, String offeringId, DateTime start, DateTime end) async {
    if (mockState == MockState.error) throw Exception("Room availability error");
    // return rooms based on offeringId

    List<RoomModel> rooms = [
      RoomModel(id: "r1", number: "101", status: RoomStatus.vacant, offeringId: "o1"),
      RoomModel(id: "r2", number: "102", status: RoomStatus.booked, offeringId: "o1"),
      RoomModel(id: "r3", number: "103", status: RoomStatus.vacant, offeringId: "o2"),
      RoomModel(id: "r4", number: "104", status: RoomStatus.vacant, offeringId: "o2"),
      RoomModel(id: "r5", number: "105", status: RoomStatus.vacant, offeringId: "o3"),
      RoomModel(id: "r6", number: "106", status: RoomStatus.vacant, offeringId: "o3"),
      RoomModel(id: "r7", number: "107", status: RoomStatus.vacant, offeringId: "o3"),
    ];
    return rooms.where((r) => r.offeringId == offeringId).toList();
  }
}
