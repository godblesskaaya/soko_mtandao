import 'package:soko_mtandao/core/constants/roles.dart';

class AccessProfile {
  final UserRole activePersona;
  final List<UserRole> availablePersonas;
  final String? selectedPath;
  final String onboardingStatus;
  final String onboardingStep;
  final bool hasSeenOnboarding;
  final String staffAssociationStatus;
  final String managerApplicationStatus;
  final String kycStatus;
  final int managedHotelCount;

  const AccessProfile({
    required this.activePersona,
    required this.availablePersonas,
    required this.selectedPath,
    required this.onboardingStatus,
    required this.onboardingStep,
    required this.hasSeenOnboarding,
    required this.staffAssociationStatus,
    required this.managerApplicationStatus,
    required this.kycStatus,
    required this.managedHotelCount,
  });

  factory AccessProfile.guest() {
    return const AccessProfile(
      activePersona: UserRole.guest,
      availablePersonas: <UserRole>[],
      selectedPath: null,
      onboardingStatus: 'not_started',
      onboardingStep: 'welcome',
      hasSeenOnboarding: false,
      staffAssociationStatus: 'none',
      managerApplicationStatus: 'none',
      kycStatus: 'pending',
      managedHotelCount: 0,
    );
  }

  factory AccessProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = (json['roles'] as List? ?? const <dynamic>[])
        .map((value) => roleFromString(value.toString()))
        .where((role) => role != UserRole.guest)
        .toList(growable: false);

    final dedupedRoles = <UserRole>[];
    for (final role in rawRoles) {
      if (!dedupedRoles.contains(role)) {
        dedupedRoles.add(role);
      }
    }

    final activePersona =
        roleFromString((json['active_persona'] ?? 'guest').toString());

    return AccessProfile(
      activePersona: activePersona,
      availablePersonas: dedupedRoles,
      selectedPath: json['selected_onboarding_path']?.toString(),
      onboardingStatus:
          (json['onboarding_status'] ?? 'not_started').toString(),
      onboardingStep: (json['onboarding_step'] ?? 'welcome').toString(),
      hasSeenOnboarding: json['has_seen_onboarding'] == true,
      staffAssociationStatus:
          (json['staff_association_status'] ?? 'none').toString(),
      managerApplicationStatus:
          (json['manager_application_status'] ?? 'none').toString(),
      kycStatus: (json['kyc_status'] ?? 'pending').toString(),
      managedHotelCount: (json['managed_hotel_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool hasPersona(UserRole role) => availablePersonas.contains(role);

  bool get hasMultiplePersonas => availablePersonas.length > 1;

  bool get needsInitialPathSelection => !hasSeenOnboarding || selectedPath == null;

  bool get isOnboardingComplete => onboardingStatus == 'completed';

  bool get isManagerPending =>
      selectedPath == 'manage_hotel' &&
      const {'draft', 'submitted', 'under_review'}
          .contains(managerApplicationStatus);

  bool get isManagerRejected =>
      selectedPath == 'manage_hotel' && managerApplicationStatus == 'rejected';

  bool get isStaffPending =>
      selectedPath == 'join_team' && staffAssociationStatus == 'pending';

  bool get isStaffRejected =>
      selectedPath == 'join_team' && staffAssociationStatus == 'rejected';

  bool get canUseStaffPersona =>
      hasPersona(UserRole.staff) && staffAssociationStatus == 'accepted';

  bool get canUseHotelAdminPersona =>
      hasPersona(UserRole.hotelAdmin) &&
      (managerApplicationStatus == 'approved' || managedHotelCount > 0);

  bool get hasActiveOperatorOnboarding =>
      selectedPath == 'manage_hotel'
          ? !canUseHotelAdminPersona
          : selectedPath == 'join_team'
              ? !canUseStaffPersona
              : false;

  String get onboardingSummary {
    if (selectedPath == 'manage_hotel') {
      switch (managerApplicationStatus) {
        case 'approved':
          return 'Approved for hotel management';
        case 'rejected':
          return 'Manager application needs updates';
        case 'submitted':
        case 'under_review':
          return 'Manager application under review';
        case 'draft':
          return 'Manager application draft in progress';
      }
      return 'Manager onboarding in progress';
    }

    if (selectedPath == 'join_team') {
      switch (staffAssociationStatus) {
        case 'accepted':
          return 'Staff access approved';
        case 'rejected':
          return 'Staff request was rejected';
        case 'pending':
          return 'Staff request pending review';
      }
      return 'Staff onboarding in progress';
    }

    if (selectedPath == 'customer') {
      return 'Customer access ready';
    }

    return 'Choose how you want to use the app';
  }
}
