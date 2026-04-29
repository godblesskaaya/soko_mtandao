import 'dart:convert';

import 'package:soko_mtandao/features/hotel_detail/data/models/amenity_model.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';

class ManagerHotelModel extends ManagerHotel {
  ManagerHotelModel({
    required String id,
    required String name,
    required double rating,
    required List<String> images,
    required String description,
    required List<Amenity> amenities,
    required String region,
    required String country,
    required String city,
    required String address,
    required String phoneNumber,
    required String email,
    String? website,
    String? checkInFrom,
    String? checkInUntil,
    String? checkOutUntil,
    List<String> stayRules = const [],
    List<String> checkInRequirements = const [],
    required double lat,
    required double lng,
    int? totalRooms,
  }) : super(
          id: id,
          name: name,
          address: address,
          description: description,
          images: images,
          amenities: amenities,
          lat: lat,
          lng: lng,
          rating: rating,
          totalRooms: 0,
          region: region,
          country: country,
          city: city,
          phoneNumber: phoneNumber,
          email: email,
          website: website,
          checkInFrom: checkInFrom,
          checkInUntil: checkInUntil,
          checkOutUntil: checkOutUntil,
          stayRules: stayRules,
          checkInRequirements: checkInRequirements,
        );

  factory ManagerHotelModel.fromJson(Map<String, dynamic> json) {
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
          (rawImages as List?)?.map((image) => image.toString()).toList() ?? [];
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

    return ManagerHotelModel(
      id: json['id'].toString(),
      name: json['name'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      region: json['region'],
      country: json['country'],
      city: json['city'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      website: json['website'],
      lat: json['lat'],
      lng: json['lng'],
      address: json['address'],
      totalRooms: json['total_rooms'],
      images: parsedImages,
      description: json['description'] ?? '',
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

  factory ManagerHotelModel.fromEntity(ManagerHotel entity) {
    return ManagerHotelModel(
      id: entity.id,
      name: entity.name,
      address: entity.address,
      description: entity.description,
      images: entity.images,
      amenities: entity.amenities,
      lat: entity.lat,
      lng: entity.lng,
      rating: entity.rating,
      totalRooms: entity.totalRooms,
      region: entity.region,
      country: entity.country,
      city: entity.city,
      phoneNumber: entity.phoneNumber,
      email: entity.email,
      website: entity.website,
      checkInFrom: entity.checkInFrom,
      checkInUntil: entity.checkInUntil,
      checkOutUntil: entity.checkOutUntil,
      stayRules: entity.stayRules,
      checkInRequirements: entity.checkInRequirements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rating': rating,
      'region': region,
      'country': country,
      'city': city,
      'address': address,
      'phoneNumber': phoneNumber,
      'email': email,
      'website': website,
      'check_in_from': checkInFrom,
      'check_in_until': checkInUntil,
      'check_out_until': checkOutUntil,
      'stay_rules': stayRules,
      'check_in_requirements': checkInRequirements,
      'lat': lat,
      'lng': lng,
      'totalRooms': totalRooms,
      'images': images,
      'description': description,
      'amenities':
          amenities.map((a) => AmenityModel.fromEntity(a).toJson()).toList(),
    };
  }
}
