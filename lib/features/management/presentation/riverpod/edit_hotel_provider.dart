import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/failure_mapper.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/editable_image.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditHotelState {
  final bool isLoading;
  final Failure? error;

  const EditHotelState({
    this.isLoading = false,
    this.error,
  });

  EditHotelState copyWith({
    bool? isLoading,
    Failure? error,
  }) {
    return EditHotelState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EditHotelNotifier extends StateNotifier<EditHotelState> {
  EditHotelNotifier() : super(const EditHotelState());

  final _supabase = Supabase.instance.client;

  Future<void> updateHotel({
    required String hotelId,
    required String name,
    required String address,
    required String description,
    required List<EditableImage> images,
    required List<ManagerAmenity> amenities,
    required double lat,
    required double lng,
    required int totalRooms,
    required String region,
    required String country,
    required String city,
    required String phoneNumber,
    required String email,
    String? checkInFrom,
    String? checkInUntil,
    String? checkOutUntil,
    required List<String> stayRules,
    required List<String> checkInRequirements,
    String? website,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      /// 1. Upload only NEW images
      final finalImageUrls = <String>[];

      for (final image in images) {
        if (image.isRemote) {
          finalImageUrls.add(image.path);
        } else {
          final file = File(image.path);
          final fileName =
              "${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}";

          await _supabase.storage.from('hotel-images').upload(fileName, file);

          final publicUrl =
              _supabase.storage.from('hotel-images').getPublicUrl(fileName);

          finalImageUrls.add(publicUrl);
        }
      }

      /// 2. Update hotel
      await _supabase.from('hotels').update({
        "name": name,
        "address": address,
        "description": description,
        "images": finalImageUrls,
        "location": 'SRID=4326;POINT($lng $lat)',
        "total_rooms": totalRooms,
        "region": region,
        "country": country,
        "city": city,
        "phone_number": phoneNumber,
        "email": email,
        "check_in_from": checkInFrom,
        "check_in_until": checkInUntil,
        "check_out_until": checkOutUntil,
        "stay_rules": stayRules,
        "check_in_requirements": checkInRequirements,
        "website": website,
      }).eq('id', hotelId);

      /// 3. Sync amenities (simple approach)
      await _supabase.from('hotel_amenities').delete().eq('hotel_id', hotelId);

      for (final amenity in amenities) {
        await _supabase.from('hotel_amenities').insert({
          "hotel_id": hotelId,
          "amenity_id": amenity.amenityId,
        });
      }
    } catch (e) {
      state = state.copyWith(error: failureFromError(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final editHotelProvider =
    StateNotifierProvider<EditHotelNotifier, EditHotelState>((ref) {
  return EditHotelNotifier();
});
