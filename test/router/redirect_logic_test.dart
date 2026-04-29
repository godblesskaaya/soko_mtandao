import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/models/access_profile.dart';
import 'package:soko_mtandao/router/redirect_logic.dart';
import 'package:soko_mtandao/router/route_names.dart';

void main() {
  group('globalRedirect', () {
    test('redirects unauthenticated private access to login', () {
      final redirect = globalRedirect(
        Uri.parse(RouteNames.hotelAdminHome),
        isLoggedIn: false,
        role: null,
        accessProfile: AccessProfile.guest(),
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.login);
    });

    test('logged in users with no chosen path are sent to onboarding hub', () {
      final profile = _profile();

      final redirect = globalRedirect(
        Uri.parse(RouteNames.login),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.onboardingHub);
    });

    test('completed customer onboarding goes to customer home from splash', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.splash),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.guestHome);
    });

    test('pending manager applicants cannot open hotel admin routes', () {
      final profile = _profile(
        selectedPath: 'manage_hotel',
        hasSeenOnboarding: true,
        onboardingStatus: 'in_progress',
        managerApplicationStatus: 'submitted',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.hotelAdminHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.pendingAccess);
    });

    test('approved hotel admins can stay in manager workspace', () {
      final profile = _profile(
        activePersona: UserRole.hotelAdmin,
        availablePersonas: const [UserRole.customer, UserRole.hotelAdmin],
        selectedPath: 'manage_hotel',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
        managerApplicationStatus: 'approved',
        managedHotelCount: 1,
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.hotelAdminHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, isNull);
    });

    test('pending staff access is routed to pending screen', () {
      final profile = _profile(
        selectedPath: 'join_team',
        hasSeenOnboarding: true,
        onboardingStatus: 'in_progress',
        staffAssociationStatus: 'pending',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.staffHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.pendingAccess);
    });

    test('non system admins are kept out of system admin routes', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.systemAdminHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.guestHome);
    });

    test('completed users are redirected away from onboarding hub', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.onboardingHub),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.guestHome);
    });
  });
}

AccessProfile _profile({
  UserRole activePersona = UserRole.customer,
  List<UserRole> availablePersonas = const [UserRole.customer],
  String? selectedPath,
  String onboardingStatus = 'not_started',
  String onboardingStep = 'welcome',
  bool hasSeenOnboarding = false,
  String staffAssociationStatus = 'none',
  String managerApplicationStatus = 'none',
  String kycStatus = 'pending',
  int managedHotelCount = 0,
}) {
  return AccessProfile(
    activePersona: activePersona,
    availablePersonas: availablePersonas,
    selectedPath: selectedPath,
    onboardingStatus: onboardingStatus,
    onboardingStep: onboardingStep,
    hasSeenOnboarding: hasSeenOnboarding,
    staffAssociationStatus: staffAssociationStatus,
    managerApplicationStatus: managerApplicationStatus,
    kycStatus: kycStatus,
    managedHotelCount: managedHotelCount,
  );
}
