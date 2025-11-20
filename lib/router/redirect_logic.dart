// Central redirect logic used by router — relies on providers passed in at runtime

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/roles.dart';
import 'route_names.dart';

String? globalRedirect(Uri location, {required bool isLoggedIn, required UserRole? role, required bool hasRedirectedAfterLogin}) {
  final path = location.path;

  // If not logged in and trying to access auth-protected routes
  if (!isLoggedIn) {
    // allow access to guest/home, login, signup, splash
    if (path == RouteNames.guestHome || path == RouteNames.login || path == RouteNames.signup || path == RouteNames.splash || path == RouteNames.bookings || path == RouteNames.hotelDetail) {
      return null;
    }
    // return RouteNames.login;
    return null;
  }

  // if logged in, role is hoteladmin and coming from login page redirect to hotel admin home
  if (isLoggedIn && role == UserRole.hotelAdmin && !hasRedirectedAfterLogin) {
    return RouteNames.hotelAdminHome;
  }

  // If logged in but role doesn't match admin area
  if (path.startsWith('/hotel-admin') && role != UserRole.hotelAdmin) {
    return RouteNames.guestHome; // or a 403 page
  }
  if (path.startsWith('/system-admin') && role != UserRole.systemAdmin) {
    return RouteNames.guestHome;
  }

  // Allow
  return null;
}
