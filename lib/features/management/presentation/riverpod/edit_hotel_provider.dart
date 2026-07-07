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

      final managerUserId = _supabase.auth.currentUser?.id;
      if (managerUserId == null || managerUserId.isEmpty) {
        throw Exception('Authentication required to upload hotel images.');
      }

      /// 1. Upload only NEW images
      final finalImageUrls = <String>[];
      final uploadedStoragePaths = <String>[];

      for (final image in images) {
        if (image.isRemote) {
          finalImageUrls.add(image.path);
        } else {
          final file = File(image.path);
          final fileName =
              "${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}";
          final storagePath = "$managerUserId/$fileName";

          await _supabase.storage.from('hotel-images').upload(storagePath, file);

          final publicUrl =
              _supabase.storage.from('hotel-images').getPublicUrl(storagePath);

          finalImageUrls.add(publicUrl);
          uploadedStoragePaths.add(storagePath);
        }
      }

      try {
        await _supabase.rpc('upsert_managed_hotel', params: {
          'p_hotel_id': hotelId,
          'p_name': name.trim(),
          'p_address': address.trim(),
          'p_description': description.trim(),
          'p_images': finalImageUrls,
          'p_amenity_ids': amenities
              .map((amenity) => amenity.amenityId)
              .where((id) => id.trim().isNotEmpty)
              .toSet()
              .toList(),
          'p_lat': lat,
          'p_lng': lng,
          'p_total_rooms': totalRooms,
          'p_region': region.trim(),
          'p_country': country.trim(),
          'p_city': city.trim(),
          'p_phone_number': phoneNumber.trim(),
          'p_email': email.trim(),
          'p_check_in_from': checkInFrom,
          'p_check_in_until': checkInUntil,
          'p_check_out_until': checkOutUntil,
          'p_stay_rules': stayRules,
          'p_check_in_requirements': checkInRequirements,
          'p_website': website,
          'p_is_active': true,
        });
      } catch (_) {
        if (uploadedStoragePaths.isNotEmpty) {
          await _supabase.storage
              .from('hotel-images')
              .remove(uploadedStoragePaths);
        }
        rethrow;
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
