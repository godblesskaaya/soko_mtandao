import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import '../constants/roles.dart';
import 'user_service.dart';
import 'auth_service.dart';

/// AuthNotifier is a ChangeNotifier used by GoRouter's refreshListenable.
/// It keeps a cached sync view of: isLoggedIn, role, hasHotelAssociation.
/// It also exposes helper methods to sign in / out.
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;
  StreamSubscription<AuthState>? _authSub;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _isRoleResolved = true;
  bool get isRoleResolved => _isRoleResolved;

  bool _isInPasswordRecovery = false;
  bool get isInPasswordRecovery => _isInPasswordRecovery;

  UserRole _role = UserRole.guest;
  UserRole get role => _role;

  bool _staffHasHotel = false;
  bool get staffHasHotel => _staffHasHotel;

  bool _hasRedirectedAfterLogin = false;
  bool get hasRedirectedAfterLogin => _hasRedirectedAfterLogin;

  AuthNotifier(this._authService, this._userService) {
    _init();
  }

  Future<void> _init() async {
    // Initialize current state
    _updateFromSession();

    // Listen to Supabase auth changes
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      /// Detect password recovery
      if (event == AuthChangeEvent.passwordRecovery) {
        _isInPasswordRecovery = true;
      }

      /// Clear recovery mode on sign in / sign out
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        _isInPasswordRecovery = false;
      }

      // event contains session & event type
      _updateFromSession();
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  void _updateFromSession() {
    final session = _authService.session;

    // 🚨 During password recovery, do NOT treat as logged in
    if (_isInPasswordRecovery) {
      _isLoggedIn = false;
      _isRoleResolved = true;
      _role = UserRole.guest;
      _staffHasHotel = false;
      return;
    }

    _isLoggedIn = session != null;
    // default to guest; we'll try to fetch role synchronously-ish (async below)
    if (!_isLoggedIn) {
      _isRoleResolved = true;
      _role = UserRole.guest;
      _staffHasHotel = false;
      return;
    }
    _isRoleResolved = false;
    // fire-and-forget fetch role & association, then notify when done
    _fetchRoleAndAssoc();
  }

  Future<void> _fetchRoleAndAssoc() async {
    final uid = _authService.userId;
    if (uid == null) {
      _isRoleResolved = true;
      _role = UserRole.guest;
      _staffHasHotel = false;
      notifyListeners();
      return;
    }

    try {
      final r = await _userService.fetchUserRole(uid);
      _role = r;
      if (_role == UserRole.staff) {
        _staffHasHotel = await _userService.staffHasHotelAssociation(uid);
      } else {
        _staffHasHotel = false;
      }
    } catch (e, stackTrace) {
      ErrorReporter.report(
        e,
        stackTrace,
        source: 'auth_notifier.fetchRoleAndAssoc',
        context: {'uid': uid},
      );
      // keep defaults on error
      _role = UserRole.guest;
      _staffHasHotel = false;
    }
    _isRoleResolved = true;
    notifyListeners();
  }

  // Expose simple auth helpers used by UI
  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
    // after sign-in Supabase will trigger onAuthStateChange which updates state
  }

  Future<void> signUp(
      {required String email,
      required String password,
      Map<String, dynamic>? data}) async {
    await _authService.signUp(email: email, password: password, data: data);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _hasRedirectedAfterLogin = false;
    // onAuthStateChange will update state
  }

  void markRedirectDone() {
    _hasRedirectedAfterLogin = true;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
