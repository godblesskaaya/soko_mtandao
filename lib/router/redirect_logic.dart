// Central redirect logic used by router.

import '../core/constants/roles.dart';
import 'route_names.dart';

String? globalRedirect(
  Uri location, {
  required bool isLoggedIn,
  required UserRole? role,
  required bool hasRedirectedAfterLogin,
  required bool isInPasswordRecovery,
}) {
  final path = location.path;

  bool matches(String template) {
    final staticPrefix = template.split('/:').first;
    return path == staticPrefix || path.startsWith('$staticPrefix/');
  }

  // Allow reset page only during recovery mode.
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

  // Logged-in users should not remain on auth pages.
  if (path == RouteNames.login ||
      path == RouteNames.signup ||
      path == RouteNames.forgotPassword) {
    if (role == UserRole.systemAdmin) return RouteNames.systemAdminHome;
    if (role == UserRole.hotelAdmin) return RouteNames.hotelAdminHome;
    if (role == UserRole.staff) return RouteNames.staffHome;
    return RouteNames.guestHome;
  }

  // First role redirect after login.
  if (isLoggedIn && role == UserRole.hotelAdmin && !hasRedirectedAfterLogin) {
    return RouteNames.hotelAdminHome;
  }

  // Role-gated admin areas.
  if (path.startsWith('/hotel-admin') && role != UserRole.hotelAdmin) {
    return RouteNames.guestHome;
  }
  if (path.startsWith('/system-admin') && role != UserRole.systemAdmin) {
    return RouteNames.guestHome;
  }

  return null;
}
