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
        );

  factory ManagerHotelModel.fromJson(Map<String, dynamic> json) {
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
      images: json['images'] is String ? List<String>.from(jsonDecode(json['images'])) :
        (json['images'] as List<dynamic>?)
              ?.map((image) => image.toString())
              .toList() ??
          [],
      description: json['description'] ?? '',
      amenities: [],
      // (json['amenities'] as List<dynamic>?)
      //         ?.map((amenity) => AmenityModel.fromJson(amenity))
      //         .toList() ??
      //     [],
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
      'lat': lat,
      'lng': lng,
      'totalRooms': totalRooms,
      'images': images,
      'description': description,
      'amenities': amenities.map((a) => AmenityModel.fromEntity(a).toJson()).toList(),
    };
  }
}
