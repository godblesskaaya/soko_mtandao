import 'dart:convert';

import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/models/access_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  Future<AccessProfile> fetchAccessProfile(String userId) async {
    if (userId.isEmpty) return AccessProfile.guest();
    final response = await _supabase.rpc('get_current_user_access_profile');
    if (response is Map<String, dynamic>) {
      return AccessProfile.fromJson(response);
    }
    if (response is Map) {
      return AccessProfile.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    if (response is String && response.trim().isNotEmpty) {
      final decoded = jsonDecode(response);
      if (decoded is Map) {
        return AccessProfile.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }
    return AccessProfile.guest();
  }

  Future<UserRole> fetchUserRole(String userId) async {
    final profile = await fetchAccessProfile(userId);
    return profile.activePersona;
  }

  Future<void> setActivePersona(UserRole role) async {
    await _supabase.rpc('set_active_persona', params: {
      'p_persona': roleToStorageString(role),
    });
  }

  Future<void> chooseOnboardingPath(String path) async {
    await _supabase.rpc('choose_onboarding_path', params: {'p_path': path});
  }

  Future<void> saveManagerApplicationDraft(Map<String, dynamic> hotelPayload) {
    return _supabase.rpc('save_manager_application_draft', params: {
      'p_hotel_payload': hotelPayload,
    });
  }

  Future<void> submitManagerApplication(Map<String, dynamic> hotelPayload) {
    return _supabase.rpc('submit_manager_application', params: {
      'p_hotel_payload': hotelPayload,
    });
  }

  Future<void> submitStaffJoinRequest({
    required String hotelId,
    required String staffTitle,
    String? note,
  }) {
    return _supabase.rpc('submit_staff_join_request', params: {
      'p_hotel_id': hotelId,
      'p_staff_title': staffTitle,
      'p_note': note,
    });
  }

  Future<void> acceptStaffInvite(String token) {
    return _supabase.rpc('accept_staff_invite', params: {'p_token': token});
  }
}
