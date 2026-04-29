import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/errors/failure_mapper.dart';
import 'package:soko_mtandao/core/errors/failures.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_amenity.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
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

      final urls = <String>[];
      for (final path in images) {
        final file = File(path);
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}";

        final uploadRes =
            await _supabase.storage.from('hotel-images').upload(fileName, file);

        if (uploadRes.isEmpty) {
          throw Exception("Image upload failed");
        }

        final publicUrl =
            _supabase.storage.from('hotel-images').getPublicUrl(fileName);
        urls.add(publicUrl);
      }

      final response = await _supabase
          .from('hotels')
          .insert({
            "name": name,
            "address": address,
            "description": description,
            "images": urls,
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
            "manager_user_id": _supabase.auth.currentUser?.id,
          })
          .select()
          .single();

      final hotel = ManagerHotel(
        id: response['id'].toString(),
        name: name,
        address: address,
        description: description,
        images: urls,
        lat: double.tryParse(lat) ?? 0.0,
        lng: double.tryParse(lng) ?? 0.0,
        rating: 0.0,
        totalRooms: totalRooms,
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

      for (final amenity in amenities) {
        await _supabase.from('hotel_amenities').insert({
          "hotel_id": hotel.id,
          "amenity_id": amenity.amenityId,
        });
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
