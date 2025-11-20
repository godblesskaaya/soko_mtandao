// models/hotel_model.dart
import 'dart:convert';

import '../../domain/entities/hotel.dart';
import '../../domain/entities/amenity.dart';

class HotelModel extends Hotel {
  HotelModel({
    required super.id,
    required super.name,
    required super.description,
    required super.address,
    required super.rating,
    required super.images,
    required super.amenities,
  });
  // factory constructor to create a HotelModel from hotel entity
  factory HotelModel.fromEntity(Hotel hotel) {
    return HotelModel(
      id: hotel.id,
      name: hotel.name,
      description: hotel.description,
      address: hotel.address,
      rating: hotel.rating,
      images: hotel.images,
      amenities: hotel.amenities,
    );
  }

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    return HotelModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      images: json['images'] is String ? List<String>.from(jsonDecode(json['images'])) :
        (json['images'] as List?)?.map((e) => e as String).toList() ?? [],
      amenities: [],
      // amenities: (json['amenities'] as List?)
      //     ?.map((a) => Amenity(id: a['id'], name: a['name'], icon: a['icon']))
      //     .toList() ?? [],
    );
  }

  // to JSON method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'rating': rating,
      'images': images,
      'amenities': amenities.map((a) => {
        'id': a.id,
        'name': a.name,
        'icon': a.icon,
      }).toList(),
    };
  }
}
