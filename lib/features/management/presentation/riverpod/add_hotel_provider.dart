import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failure_mapper.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddHotelState {
  final bool isLoading;
  final Failure? error;

  AddHotelState({this.isLoading = false, this.error});

  AddHotelState copyWith({bool? isLoading, Failure? error}) {
    return AddHotelState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AddHotelNotifier extends StateNotifier<AddHotelState> {
  AddHotelNotifier() : super(AddHotelState());

  final _supabase = Supabase.instance.client;

  Future<void> addHotel({
    required String name,
    required String address,
    required String description,
    required List<String> images,
    required List<ManagerAmenity> amenities,
    required String lat,
    required String lng,
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
      state = state.copyWith(isLoading: true, error: null);

      final managerUserId = _supabase.auth.currentUser?.id;
      if (managerUserId == null || managerUserId.isEmpty) {
        throw Exception('Authentication required to upload hotel images.');
      }

      final urls = <String>[];
      final uploadedStoragePaths = <String>[];
      for (final path in images) {
        final file = File(path);
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}";
        final storagePath = "$managerUserId/$fileName";

        final uploadRes = await _supabase.storage
            .from('hotel-images')
            .upload(storagePath, file);

        if (uploadRes.isEmpty) {
          throw Exception("Image upload failed");
        }

        final publicUrl =
            _supabase.storage.from('hotel-images').getPublicUrl(storagePath);
        urls.add(publicUrl);
        uploadedStoragePaths.add(storagePath);
      }

      try {
        await _supabase.rpc('upsert_managed_hotel', params: {
          'p_hotel_id': null,
          'p_name': name.trim(),
          'p_address': address.trim(),
          'p_description': description.trim(),
          'p_images': urls,
          'p_amenity_ids': amenities
              .map((amenity) => amenity.amenityId)
              .where((id) => id.trim().isNotEmpty)
              .toSet()
              .toList(),
          'p_lat': double.tryParse(lat),
          'p_lng': double.tryParse(lng),
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
      ErrorReporter.report(e, StackTrace.current,
          source: 'add_hotel_provider.addHotel');
      state = state.copyWith(error: failureFromError(e));
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final addHotelProvider =
    StateNotifierProvider<AddHotelNotifier, AddHotelState>((ref) {
  return AddHotelNotifier();
});
