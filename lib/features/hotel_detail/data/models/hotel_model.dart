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
    super.checkInFrom,
    super.checkInUntil,
    super.checkOutUntil,
    super.stayRules,
    super.checkInRequirements,
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
      checkInFrom: hotel.checkInFrom,
      checkInUntil: hotel.checkInUntil,
      checkOutUntil: hotel.checkOutUntil,
      stayRules: hotel.stayRules,
      checkInRequirements: hotel.checkInRequirements,
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
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return const <String>[];
      if (raw is List) {
        return raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return const <String>[];
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
          }
        } catch (_) {}
        return trimmed
            .split('\n')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    return HotelModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      images: parsedImages,
      checkInFrom: (json['check_in_from'] ?? '').toString().trim().isEmpty
          ? null
          : (json['check_in_from']).toString().trim(),
      checkInUntil: (json['check_in_until'] ?? '').toString().trim().isEmpty
          ? null
          : (json['check_in_until']).toString().trim(),
      checkOutUntil: (json['check_out_until'] ?? '').toString().trim().isEmpty
          ? null
          : (json['check_out_until']).toString().trim(),
      stayRules: parseStringList(json['stay_rules']),
      checkInRequirements: parseStringList(json['check_in_requirements']),
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
      'check_in_from': checkInFrom,
      'check_in_until': checkInUntil,
      'check_out_until': checkOutUntil,
      'stay_rules': stayRules,
      'check_in_requirements': checkInRequirements,
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
