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

  Hotel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.rating,
    required this.images,
    required this.amenities,
  });
}
