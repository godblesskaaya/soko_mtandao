import '../core/constants/roles.dart';
import '../core/models/access_profile.dart';
import 'route_names.dart';

String? globalRedirect(
  Uri location, {
  required bool isLoggedIn,
  required UserRole? role,
  required AccessProfile accessProfile,
  required bool isInPasswordRecovery,
}) {
  final path = location.path;

  bool matches(String template) {
    final staticPrefix = template.split('/:').first;
    return path == staticPrefix || path.startsWith('$staticPrefix/');
  }

  if (isInPasswordRecovery && path == RouteNames.resetPassword) {
    return null;
  }

  if (isInPasswordRecovery && path != RouteNames.resetPassword) {
    return RouteNames.resetPassword;
  }

  if (!isLoggedIn) {
    final isPublicRoute = path == RouteNames.splash ||
        path == RouteNames.guestHome ||
        path == RouteNames.hotels ||
        path == RouteNames.bookings ||
        path == RouteNames.login ||
        path == RouteNames.signup ||
        path == RouteNames.forgotPassword ||
        path == RouteNames.bookingInitiate ||
        path.startsWith('${RouteNames.bookingReview}/') ||
        path.startsWith('${RouteNames.payment}/') ||
        path.startsWith('${RouteNames.bookingConfirmation}/') ||
        path.startsWith(RouteNames.deleteAccount.split('/:').first) ||
        matches(RouteNames.hotelDetail);

    return isPublicRoute ? null : RouteNames.login;
  }

  final isAuthPage = path == RouteNames.login ||
      path == RouteNames.signup ||
      path == RouteNames.forgotPassword;
  if (isAuthPage) {
    return accessProfile.needsInitialPathSelection ||
            (accessProfile.hasActiveOperatorOnboarding &&
                accessProfile.activePersona == UserRole.customer)
        ? RouteNames.onboardingHub
        : _homeForAccess(accessProfile);
  }

  if (path == RouteNames.splash) {
    return _homeForAccess(accessProfile);
  }

  final onboardingPaths = {
    RouteNames.onboardingHub,
    RouteNames.managerOnboarding,
    RouteNames.staffOnboarding,
    RouteNames.pendingAccess,
    RouteNames.requestHotelAssociation,
  };

  if (path == RouteNames.onboardingHub &&
      !accessProfile.needsInitialPathSelection &&
      !accessProfile.hasActiveOperatorOnboarding) {
    return _homeForAccess(accessProfile);
  }

  if ((path == RouteNames.managerOnboarding ||
          path == RouteNames.staffOnboarding ||
          path == RouteNames.pendingAccess ||
          path == RouteNames.requestHotelAssociation) &&
      accessProfile.selectedPath == null &&
      !accessProfile.needsInitialPathSelection) {
    return RouteNames.onboardingHub;
  }

  final isHotelAdminRoute = path.startsWith('/hotel-admin') ||
      matches(RouteNames.managerHotel) ||
      matches(RouteNames.hotelList) ||
      path == RouteNames.addHotel ||
      matches(RouteNames.offerings) ||
      matches(RouteNames.addOfferings) ||
      matches(RouteNames.rooms) ||
      matches(RouteNames.addRooms) ||
      matches(RouteNames.editHotel) ||
      matches(RouteNames.editRoom) ||
      matches(RouteNames.editOffering) ||
      matches(RouteNames.roomDetails) ||
      matches(RouteNames.roomBookings) ||
      matches(RouteNames.hotelBookings) ||
      matches(RouteNames.managerPayments) ||
      path == RouteNames.settings ||
      path == RouteNames.managerNotifications ||
      matches(RouteNames.managerBookingDetail) ||
      path == RouteNames.managerTeam;

  if (isHotelAdminRoute &&
      !(accessProfile.canUseHotelAdminPersona &&
          role == UserRole.hotelAdmin)) {
    return accessProfile.hasActiveOperatorOnboarding
        ? RouteNames.pendingAccess
        : RouteNames.guestHome;
  }

  if (path.startsWith('/system-admin') && role != UserRole.systemAdmin) {
    return RouteNames.guestHome;
  }

  if (path.startsWith('/staff/') &&
      path != RouteNames.staffOnboarding &&
      path != RouteNames.requestHotelAssociation &&
      !(accessProfile.canUseStaffPersona && role == UserRole.staff)) {
    return accessProfile.hasActiveOperatorOnboarding
        ? RouteNames.pendingAccess
        : RouteNames.guestHome;
  }

  if (onboardingPaths.contains(path)) {
    return null;
  }

  return null;
}

String _homeForAccess(AccessProfile accessProfile) {
  switch (accessProfile.activePersona) {
    case UserRole.staff:
      return accessProfile.canUseStaffPersona
          ? RouteNames.staffHome
          : RouteNames.pendingAccess;
    case UserRole.hotelAdmin:
      return accessProfile.canUseHotelAdminPersona
          ? RouteNames.hotelAdminHome
          : RouteNames.pendingAccess;
    case UserRole.systemAdmin:
      return RouteNames.systemAdminHome;
    case UserRole.customer:
    case UserRole.guest:
      return accessProfile.needsInitialPathSelection ||
              accessProfile.hasActiveOperatorOnboarding
          ? RouteNames.onboardingHub
          : RouteNames.guestHome;
  }
}
