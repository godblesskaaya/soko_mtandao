import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../hotel_detail/domain/entities/amenity.dart';

/// --- State ---
class AddHotelState {
  final bool isLoading;
  final String? errorMessage;

  AddHotelState({this.isLoading = false, this.errorMessage});

  AddHotelState copyWith({bool? isLoading, String? errorMessage}) {
    return AddHotelState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// --- Notifier ---
class AddHotelNotifier extends StateNotifier<AddHotelState> {
  AddHotelNotifier() : super(AddHotelState());

  final _supabase = Supabase.instance.client;

  Future<void> addHotel({
    required String name,
    required String address,
    required String description,
    required List<String> images, // local file paths
    required List<ManagerAmenity> amenities,
    required String lat,
    required String lng,
    required double rating,
    required int totalRooms,
    required String region,
    required String country,
    required String city,
    required String phoneNumber,
    required String email,
    String? website,
  }) async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // 1. Upload images to Supabase Storage
      final urls = <String>[];
      for (final path in images) {
        final file = File(path);
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}";

        final uploadRes = await _supabase.storage
            .from('hotel-images') // bucket name
            .upload(fileName, file);

        if (uploadRes.isEmpty) {
          throw Exception("Image upload failed");
        }

        final publicUrl =
            _supabase.storage.from('hotel-images').getPublicUrl(fileName);

        urls.add(publicUrl);
      }

      // 2. Insert hotel row into database
      final response = await _supabase.from('hotels').insert({
        "name": name,
        "address": address,
        "description": description,
        "images": urls, // ✅ remote URLs, not local paths
        "location": 'SRID=4326;POINT($lng $lat)',
        // "lat": lat,
        // "lng": lng,
        "rating": rating,
        "total_rooms": totalRooms,
        "region": region,
        "country": country,
        "city": city,
        "phone_number": phoneNumber,
        "email": email,
        "website": website,
        "manager_user_id": _supabase.auth.currentUser?.id,
        // "is_active": true,
        // "amenities": amenities.map((a) => a.name).toList(),
      }).select().single();

      if (response == null) throw Exception("Hotel insert failed");

      // Optionally map back to entity if needed
      final hotel = ManagerHotel(
        id: response['id'].toString(),
        name: name,
        address: address,
        description: description,
        images: urls,
        // amenities: amenities,
        lat: double.tryParse(lat) as double,
        lng: double.tryParse(lng) as double,
        rating: rating,
        totalRooms: totalRooms,
        region: region,
        country: country,
        city: city,
        phoneNumber: phoneNumber,
        email: email,
        website: website,
      );

      // Add amenities to amenities table linking with hotel Id
      for (final amenity in amenities) {
        await _supabase.from('hotel_amenities').insert({
          "hotel_id": hotel.id,
          "amenity_id": amenity.amenityId,
        });
      }

      // Success — for now we just log/print
      print("✅ Hotel added: ${hotel.id}");
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

/// --- Provider ---
final addHotelProvider =
    StateNotifierProvider<AddHotelNotifier, AddHotelState>((ref) {
  return AddHotelNotifier();
});
