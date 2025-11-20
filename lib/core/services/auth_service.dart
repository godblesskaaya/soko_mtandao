import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<AuthResponse> signUp({required String email, required String password, Map<String, dynamic>? data}) {
    return _supabase.auth.signUp(email: email, password: password, data: data);
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<UserResponse> updateUser({required String email, required String password, Map<String, dynamic>? data}) {
    return _supabase.auth.updateUser(
      UserAttributes(email: email, password: password, data: data),
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Session? get session => _supabase.auth.currentSession;

  bool get isLoggedIn => _supabase.auth.currentSession != null;

  User? get currentUser => _supabase.auth.currentUser;

  String? get userId => _supabase.auth.currentUser?.id;
}
