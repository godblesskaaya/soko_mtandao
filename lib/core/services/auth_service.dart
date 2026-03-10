import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<void> _audit(
    String eventType, {
    String? entityType,
    String? entityId,
    Map<String, dynamic>? payload,
    String? actorUserId,
  }) async {
    try {
      await _supabase.rpc('log_audit_event', params: {
        'p_event_type': eventType,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_payload': payload ?? const <String, dynamic>{},
        'p_actor_user_id': actorUserId,
      });
    } catch (_) {
      // Audit best-effort must not block auth flow.
    }
  }

  Future<AuthResponse> signUp(
      {required String email,
      required String password,
      Map<String, dynamic>? data}) {
    return _supabase.auth
        .signUp(email: email, password: password, data: data)
        .then((response) async {
      await _audit(
        'signup_submitted',
        entityType: 'user',
        entityId: response.user?.id,
        payload: {'email': email},
        actorUserId: response.user?.id,
      );
      return response;
    });
  }

  Future<AuthResponse> signIn(
      {required String email, required String password}) {
    return _supabase.auth
        .signInWithPassword(email: email, password: password)
        .then((response) async {
      final uid = response.user?.id;
      if (uid != null) {
        final frozen = await _supabase.rpc('is_account_frozen', params: {
          'p_user_id': uid,
        });
        if (frozen == true) {
          await _supabase.auth.signOut();
          throw const AuthException('Account is suspended. Contact support.');
        }
      }

      await _audit(
        'login_success',
        entityType: 'user',
        entityId: uid,
        payload: {'email': email},
        actorUserId: uid,
      );
      return response;
    }).catchError((error) async {
      await _audit(
        'login_failed',
        entityType: 'auth',
        payload: {'email': email, 'error': error.toString()},
      );
      throw error;
    });
  }

  Future<UserResponse> updateUser(
      {required String email,
      required String password,
      Map<String, dynamic>? data}) {
    return _supabase.auth.updateUser(
      UserAttributes(email: email, password: password, data: data),
    );
  }

  Future<void> signOut() async {
    final uid = _supabase.auth.currentUser?.id;
    await _audit(
      'logout',
      entityType: 'user',
      entityId: uid,
      actorUserId: uid,
    );
    await _supabase.auth.signOut();
  }

  Session? get session => _supabase.auth.currentSession;

  bool get isLoggedIn => _supabase.auth.currentSession != null;

  User? get currentUser => _supabase.auth.currentUser;

  String? get userId => _supabase.auth.currentUser?.id;
}
