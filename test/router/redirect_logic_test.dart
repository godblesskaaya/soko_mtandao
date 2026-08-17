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

    test('unauthenticated users can open support and legal pages', () {
      for (final route in [
        RouteNames.contactUs,
        RouteNames.termsAndConditions,
      ]) {
        final redirect = globalRedirect(
          Uri.parse(route),
          isLoggedIn: false,
          role: null,
          accessProfile: AccessProfile.guest(),
          isInPasswordRecovery: false,
        );

        expect(redirect, isNull, reason: '$route should be public');
      }
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

    test('signed in users with no chosen path cannot bypass onboarding on home',
        () {
      final profile = _profile();

      final redirect = globalRedirect(
        Uri.parse(RouteNames.guestHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.onboardingHub);
    });

    test('pending operator applicants can continue browsing as customers', () {
      final profile = _profile(
        selectedPath: 'manage_hotel',
        hasSeenOnboarding: true,
        onboardingStatus: 'in_progress',
        managerApplicationStatus: 'submitted',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.guestHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, isNull);
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

    test('does not redirect while auth is initializing', () {
      final redirect = globalRedirect(
        Uri.parse(RouteNames.hotelAdminHome),
        isLoggedIn: false,
        role: null,
        accessProfile: AccessProfile.guest(),
        isInPasswordRecovery: false,
        isAuthInitialized: false,
      );

      expect(redirect, isNull);
    });

    test('does not redirect signed in users before role is resolved', () {
      final redirect = globalRedirect(
        Uri.parse(RouteNames.hotelAdminHome),
        isLoggedIn: true,
        role: UserRole.guest,
        accessProfile: AccessProfile.guest(),
        isInPasswordRecovery: false,
        isRoleResolved: false,
      );

      expect(redirect, isNull);
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

    test('non managers cannot open parameterized hotel list route', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      final redirect = globalRedirect(
        Uri.parse('${RouteNames.hotelList}/user-1'),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.guestHome);
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

    test('customer bookings route is not mistaken for hotel bookings route', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.bookings),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, isNull);
    });

    test('plain bookings route is public for guest booking lookup', () {
      final redirect = globalRedirect(
        Uri.parse(RouteNames.bookings),
        isLoggedIn: false,
        role: null,
        accessProfile: AccessProfile.guest(),
        isInPasswordRecovery: false,
      );

      expect(redirect, isNull);
    });

    test('system admins bypass onboarding even without onboarding flags', () {
      final profile = _profile(
        activePersona: UserRole.systemAdmin,
        availablePersonas: const [UserRole.customer, UserRole.systemAdmin],
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.splash),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.systemAdminHome);
    });

    test('system admin role bypasses onboarding even if active persona is stale',
        () {
      final profile = _profile(
        activePersona: UserRole.customer,
        availablePersonas: const [UserRole.customer, UserRole.systemAdmin],
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.splash),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.systemAdminHome);
    });

    test('system admin role can open admin route even if role argument is stale',
        () {
      final profile = _profile(
        activePersona: UserRole.customer,
        availablePersonas: const [UserRole.customer, UserRole.systemAdmin],
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.systemAdminHome),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, isNull);
    });

    test('system admin role can open all system admin child routes', () {
      final profile = _profile(
        activePersona: UserRole.systemAdmin,
        availablePersonas: const [UserRole.customer, UserRole.systemAdmin],
      );

      for (final route in [
        RouteNames.systemAdminHome,
        RouteNames.systemAdminKycQueue,
        '${RouteNames.systemAdminKycQueue}/user-1',
        RouteNames.systemAdminManagerApplications,
        '${RouteNames.systemAdminManagerApplications}/app-1',
        RouteNames.systemAdminDisputes,
        '${RouteNames.systemAdminDisputes}/dispute-1',
        RouteNames.systemAdminAccounts,
        RouteNames.systemAdminCompliance,
      ]) {
        final redirect = globalRedirect(
          Uri.parse(route),
          isLoggedIn: true,
          role: profile.activePersona,
          accessProfile: profile,
          isInPasswordRecovery: false,
        );

        expect(redirect, isNull, reason: '$route should be admin-accessible');
      }
    });

    test('non system admins cannot open system admin child routes', () {
      final profile = _profile(
        selectedPath: 'customer',
        hasSeenOnboarding: true,
        onboardingStatus: 'completed',
      );

      for (final route in [
        RouteNames.systemAdminKycQueue,
        '${RouteNames.systemAdminKycQueue}/user-1',
        RouteNames.systemAdminManagerApplications,
        '${RouteNames.systemAdminManagerApplications}/app-1',
        RouteNames.systemAdminDisputes,
        '${RouteNames.systemAdminDisputes}/dispute-1',
        RouteNames.systemAdminAccounts,
        RouteNames.systemAdminCompliance,
      ]) {
        final redirect = globalRedirect(
          Uri.parse(route),
          isLoggedIn: true,
          role: profile.activePersona,
          accessProfile: profile,
          isInPasswordRecovery: false,
        );

        expect(redirect, RouteNames.guestHome,
            reason: '$route should be system-admin guarded');
      }
    });

    test('system admins are redirected away from onboarding surfaces', () {
      final profile = _profile(
        activePersona: UserRole.systemAdmin,
        availablePersonas: const [UserRole.customer, UserRole.systemAdmin],
      );

      final redirect = globalRedirect(
        Uri.parse(RouteNames.onboardingHub),
        isLoggedIn: true,
        role: profile.activePersona,
        accessProfile: profile,
        isInPasswordRecovery: false,
      );

      expect(redirect, RouteNames.systemAdminHome);
    });

    test('completed customer users can reopen onboarding hub', () {
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

      expect(redirect, isNull);
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
