// models/hotel_model.dart
import 'dart:convert';

import 'package:soko_mtandao/features/hotel_detail/data/models/amenity_model.dart';

import '../../domain/entities/hotel.dart';

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
    final amenityRows = (json['amenities'] as List?) ?? const [];
    final rawImages = json['images'];
    List<String> parsedImages;
    if (rawImages is String) {
      try {
        parsedImages = List<String>.from(jsonDecode(rawImages));
      } catch (_) {
        parsedImages = rawImages.trim().isEmpty ? [] : [rawImages];
      }
    } else {
      parsedImages =
          (rawImages as List?)?.map((e) => e.toString()).toList() ?? [];
    }

    return HotelModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      images: parsedImages,
      amenities: amenityRows
          .whereType<Map>()
          .map((row) => AmenityModel.fromJson(
              Map<String, dynamic>.from(row as Map<dynamic, dynamic>)))
          .toList(),
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
      'amenities': amenities
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'icon': a.icon,
              })
          .toList(),
    };
  }
}
