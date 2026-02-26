import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/offering.dart';

class OfferingModel extends Offering {
  OfferingModel({
    required super.id,
    required super.title,
    required super.description,
    required super.pricePerNight,
    required super.maxGuests,
    required super.amenities,
    required super.images,
  });

  factory OfferingModel.fromEntity(Offering offering) {
    return OfferingModel(
      id: offering.id,
      title: offering.title,
      description: offering.description,
      pricePerNight: offering.pricePerNight,
      maxGuests: offering.maxGuests,
      amenities: offering.amenities,
      images: offering.images,
    );
  }

  factory OfferingModel.fromJson(Map<String, dynamic> json) {
    return OfferingModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      pricePerNight: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxGuests: json['max_guests'] ?? 0,
      amenities: (json['amenities'] as List?)
              ?.map(
                  (a) => Amenity(id: a['id'], name: a['name'], icon: a['icon']))
              .toList() ??
          [],
      images: (json['images'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': pricePerNight,
      'max_guests': maxGuests,
      'amenities': amenities
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'icon': a.icon,
              })
          .toList(),
      'images': images,
    };
  }
}
