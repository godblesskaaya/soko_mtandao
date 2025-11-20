// Responsible for reading user data (hotel association) from custom tables

import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// Fetch role for the given userId
  Future<UserRole> fetchUserRole (String userId) async {
    if (userId.isEmpty) return UserRole.guest;

    final res = await _supabase
        .from('user_roles_view') // You can create a view or join logic in backend
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

    if (res == null) return UserRole.guest;

    final rolestr = res['role'];
    return roleFromString(rolestr);
  }

  /// Fetch whether staff is associated with a hotel
  Future<bool> staffHasHotelAssociation(String userId) async {
    if (userId.isEmpty) return false;

    final res = await _supabase
        .from('users')
        .select('hotel_id')
        .eq('id', userId)
        .maybeSingle();

    if (res == null) return false;
    return res['hotel_id'] != null;
  }
}
