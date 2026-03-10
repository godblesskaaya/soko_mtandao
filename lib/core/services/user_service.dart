// Responsible for reading user data (hotel association) from custom tables

import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// Fetch role for the given userId
  Future<UserRole> fetchUserRole(String userId) async {
    if (userId.isEmpty) return UserRole.guest;
    final role = await _supabase.rpc('get_current_user_role');
    if (role == null) return UserRole.guest;
    return roleFromString(role.toString());
  }

  /// Fetch whether staff is associated with a hotel
  Future<bool> staffHasHotelAssociation(String userId) async {
    if (userId.isEmpty) return false;

    final res = await _supabase
        .from('staff')
        .select('hotel_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (res == null) return false;
    return res['hotel_id'] != null;
  }
}
