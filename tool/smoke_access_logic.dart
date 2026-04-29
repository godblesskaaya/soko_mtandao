import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/models/access_profile.dart';
import 'package:soko_mtandao/router/redirect_logic.dart';
import 'package:soko_mtandao/router/route_names.dart';

void main() {
  _expect(AccessProfile.guest().activePersona == UserRole.guest,
      'Guest profile should default to guest persona.');
  _expect(AccessProfile.guest().needsInitialPathSelection,
      'Guest profile should require onboarding path selection.');

  final approvedManager = AccessProfile.fromJson({
    'active_persona': 'hotel_admin',
    'roles': ['customer', 'hotel_admin', 'customer'],
    'selected_onboarding_path': 'manage_hotel',
    'onboarding_status': 'completed',
    'onboarding_step': 'done',
    'has_seen_onboarding': true,
    'staff_association_status': 'none',
    'manager_application_status': 'approved',
    'kyc_status': 'approved',
    'managed_hotel_count': 1,
  });
  _expect(approvedManager.canUseHotelAdminPersona,
      'Approved managers should unlock hotel admin persona.');
  _expect(
    globalRedirect(
      Uri.parse(RouteNames.hotelAdminHome),
      isLoggedIn: true,
      role: approvedManager.activePersona,
      accessProfile: approvedManager,
      isInPasswordRecovery: false,
    ) ==
        null,
    'Approved hotel admins should stay inside hotel admin routes.',
  );

  final pendingStaff = _profile(
    selectedPath: 'join_team',
    hasSeenOnboarding: true,
    onboardingStatus: 'in_progress',
    staffAssociationStatus: 'pending',
  );
  _expect(pendingStaff.hasActiveOperatorOnboarding,
      'Pending staff onboarding should be considered active.');
  _expect(
    globalRedirect(
      Uri.parse(RouteNames.staffHome),
      isLoggedIn: true,
      role: pendingStaff.activePersona,
      accessProfile: pendingStaff,
      isInPasswordRecovery: false,
    ) ==
        RouteNames.pendingAccess,
    'Pending staff access should route to the pending access screen.',
  );

  final completedCustomer = _profile(
    selectedPath: 'customer',
    hasSeenOnboarding: true,
    onboardingStatus: 'completed',
  );
  _expect(
    globalRedirect(
      Uri.parse(RouteNames.splash),
      isLoggedIn: true,
      role: completedCustomer.activePersona,
      accessProfile: completedCustomer,
      isInPasswordRecovery: false,
    ) ==
        RouteNames.guestHome,
    'Completed customers should land on the customer home route.',
  );

  print('Access logic smoke checks passed.');
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

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
