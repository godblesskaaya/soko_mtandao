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
  int _profileRequestId = 0;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  bool _isRoleResolved = true;
  bool get isRoleResolved => _isRoleResolved;

  bool _hasAccessProfileError = false;
  bool get hasAccessProfileError => _hasAccessProfileError;

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

  void _init() {
    unawaited(_updateFromSession());

    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        _isInPasswordRecovery = true;
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        _isInPasswordRecovery = false;
      }

      unawaited(_updateFromSession());
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _updateFromSession() async {
    _profileRequestId++;
    final session = _authService.session;

    if (_isInPasswordRecovery) {
      _isLoggedIn = false;
      _isRoleResolved = true;
      _hasAccessProfileError = false;
      _accessProfile = AccessProfile.guest();
      return;
    }

    _isLoggedIn = session != null;
    if (!_isLoggedIn) {
      _isRoleResolved = true;
      _hasAccessProfileError = false;
      _accessProfile = AccessProfile.guest();
      return;
    }

    _isRoleResolved = false;
    await _fetchAccessProfile(_profileRequestId);
  }

  Future<void> _fetchAccessProfile(int requestId) async {
    final uid = _authService.userId;
    if (uid == null) {
      if (requestId != _profileRequestId) return;
      _isRoleResolved = true;
      _accessProfile = AccessProfile.guest();
      notifyListeners();
      return;
    }

    try {
      final profile = await _userService.fetchAccessProfile(uid);
      if (requestId != _profileRequestId) return;
      _accessProfile = profile;
      _hasAccessProfileError = false;
    } catch (e, stackTrace) {
      if (requestId != _profileRequestId) return;
      ErrorReporter.report(
        e,
        stackTrace,
        source: 'auth_notifier.fetchAccessProfile',
        context: {'uid': uid},
      );
      _hasAccessProfileError = true;
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
    final requestId = ++_profileRequestId;
    _isRoleResolved = false;
    _hasAccessProfileError = false;
    notifyListeners();
    await _fetchAccessProfile(requestId);
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
    await _updateFromSession();
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    final response = await _authService.signUp(
      email: email,
      password: password,
      data: data,
    );
    if (response.session != null) {
      await _updateFromSession();
    }
    return response;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _hasRedirectedAfterLogin = false;
    await _updateFromSession();
    notifyListeners();
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
