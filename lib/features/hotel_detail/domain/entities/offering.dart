// entities/offering.dart
import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';

class Offering {
  final String id;
  final String title;
  final String description;
  final double pricePerNight;
  final int maxGuests;
  final List<Amenity> amenities;
  final List<String> images;

  Offering({
    required this.id,
    required this.title,
    required this.description,
    required this.pricePerNight,
    required this.maxGuests,
    required this.amenities,
    required this.images,
  });
}
