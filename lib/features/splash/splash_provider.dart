// lib/features/splash/presentation/riverpod/splash_provider.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import '../../../../core/constants/roles.dart';

final splashRedirectProvider = FutureProvider<String>((ref) async {
  await Future.delayed(Duration(seconds: 1));
  return RouteNames.guestHome;
});

// final splashRedirectProvider = FutureProvider<String>((ref) async {
//   final authNotifier = ref.read(authNotifierProvider);
//   final role = authNotifier.role;
//   final staffAssoc = authNotifier.staffHasHotel;
  
//   // Check if staff has hotel association
//   if (role == UserRole.staff) {
//     return staffAssoc ? RouteNames.staffHome : RouteNames.requestHotelAssociation;
//   }
//   // Redirect logic based on user role
//   switch (role) {
//     case UserRole.staff:
//       return RouteNames.staffHome;
//     case UserRole.hotelAdmin:
//       return RouteNames.hotelAdminHome;
//     case UserRole.systemAdmin:
//       return RouteNames.systemAdminHome;
//     case UserRole.customer:
//       return RouteNames.guestHome;
//     case UserRole.guest:
//       return RouteNames.guestHome;
//     default:
//       return RouteNames.guestHome; // same as explore screen
//   }
// });
