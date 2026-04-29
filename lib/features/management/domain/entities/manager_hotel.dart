import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';

class ManagerHotel {
  final String id;
  final String name;
  final String address;
  final String description;
  final List<String> images;
  final List<Amenity> amenities;
  final bool isActive;
  final double lat;
  final double lng;
  final double rating;
  final String region;
  final String country;
  final String city;
  final String phoneNumber;
  final String email;
  final String? website;
  final int totalRooms;
  final String? checkInFrom;
  final String? checkInUntil;
  final String? checkOutUntil;
  final List<String> stayRules;
  final List<String> checkInRequirements;

  ManagerHotel({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    this.images = const [],
    this.amenities = const [],
    this.isActive = true,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.totalRooms,
    required this.region,
    required this.country,
    required this.city,
    required this.phoneNumber,
    required this.email,
    this.website,
    this.checkInFrom,
    this.checkInUntil,
    this.checkOutUntil,
    this.stayRules = const [],
    this.checkInRequirements = const [],
  });
}
