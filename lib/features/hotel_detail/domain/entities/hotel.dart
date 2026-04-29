// entities/hotel.dart
import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';

class Hotel {
  final String id;
  final String name;
  final String description;
  final String address;
  final double rating;
  final List<String> images;
  final List<Amenity> amenities;
  final String? checkInFrom;
  final String? checkInUntil;
  final String? checkOutUntil;
  final List<String> stayRules;
  final List<String> checkInRequirements;

  Hotel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.rating,
    required this.images,
    required this.amenities,
    this.checkInFrom,
    this.checkInUntil,
    this.checkOutUntil,
    this.stayRules = const [],
    this.checkInRequirements = const [],
  });
}
