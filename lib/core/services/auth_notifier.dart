import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soko_mtandao/core/errors/error_reporter.dart';
import 'package:soko_mtandao/core/models/access_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/roles.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// AuthNotifier is a ChangeNotifier used by GoRouter's refreshListenable.
/// It keeps a cached sync view of the authenticated session and the richer
/// access-profile payload used for onboarding + persona switching.
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

  bool _hasRedirectedAfterLogin = false;
  bool get hasRedirectedAfterLogin => _hasRedirectedAfterLogin;

  AccessProfile _accessProfile = AccessProfile.guest();
  AccessProfile get accessProfile => _accessProfile;

  UserRole get role => _accessProfile.activePersona;

  bool get staffHasHotel => _accessProfile.staffAssociationStatus == 'accepted';

  List<UserRole> get availablePersonas => _accessProfile.availablePersonas;

  AuthNotifier(this._authService, this._userService) {
    _init();
  }

  Future<void> _init() async {
    _updateFromSession();

    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        _isInPasswordRecovery = true;
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        _isInPasswordRecovery = false;
      }

      _updateFromSession();
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  void _updateFromSession() {
    final session = _authService.session;

    if (_isInPasswordRecovery) {
      _isLoggedIn = false;
      _isRoleResolved = true;
      _accessProfile = AccessProfile.guest();
      return;
    }

    _isLoggedIn = session != null;
    if (!_isLoggedIn) {
      _isRoleResolved = true;
      _accessProfile = AccessProfile.guest();
      return;
    }

    _isRoleResolved = false;
    _fetchAccessProfile();
  }

  Future<void> _fetchAccessProfile() async {
    final uid = _authService.userId;
    if (uid == null) {
      _isRoleResolved = true;
      _accessProfile = AccessProfile.guest();
      notifyListeners();
      return;
    }

    try {
      _accessProfile = await _userService.fetchAccessProfile(uid);
    } catch (e, stackTrace) {
      ErrorReporter.report(
        e,
        stackTrace,
        source: 'auth_notifier.fetchAccessProfile',
        context: {'uid': uid},
      );
      _accessProfile = AccessProfile.guest();
    }

    _isRoleResolved = true;
    notifyListeners();
  }

  bool get needsOnboardingHub =>
      _accessProfile.needsInitialPathSelection ||
      (_accessProfile.hasActiveOperatorOnboarding &&
          _accessProfile.activePersona == UserRole.customer);

  String get preferredHomeRoute {
    switch (role) {
      case UserRole.staff:
        return staffHasHotel ? '/staff/home' : '/onboarding/pending';
      case UserRole.hotelAdmin:
        return _accessProfile.canUseHotelAdminPersona
            ? '/hotel-admin/home'
            : '/onboarding/pending';
      case UserRole.systemAdmin:
        return '/system-admin/home';
      case UserRole.customer:
      case UserRole.guest:
        return needsOnboardingHub ? '/onboarding' : '/home';
    }
  }

  Future<void> refreshAccessProfile() async {
    _isRoleResolved = false;
    notifyListeners();
    await _fetchAccessProfile();
  }

  Future<void> setActivePersona(UserRole newRole) async {
    await _userService.setActivePersona(newRole);
    await refreshAccessProfile();
  }

  Future<void> chooseOnboardingPath(String path) async {
    await _userService.chooseOnboardingPath(path);
    await refreshAccessProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    await _authService.signUp(email: email, password: password, data: data);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _hasRedirectedAfterLogin = false;
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
