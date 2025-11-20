// go_router configuration with ShellRoutes for layouts, named routes, and redirect

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/booking/presentation/screens/booking_review_screen.dart';
import 'package:soko_mtandao/features/booking/presentation/screens/confirmation_screen.dart';
import 'package:soko_mtandao/features/booking/presentation/screens/payment_screen.dart';
import 'package:soko_mtandao/features/booking/presentation/screens/user_info_screen.dart';
import 'package:soko_mtandao/features/find_booking/presentation/screens/find_booking_screen.dart';
import 'package:soko_mtandao/features/find_hotels/presentation/screens/hotel_search_screen.dart';
import 'package:soko_mtandao/features/hotel_detail/presentation/screens/hotel_detail_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/add_hotel_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/add_offering_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/add_room_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/booking_list_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_dashboard_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_hotel_List_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_hotel_detail_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_room_details_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/offering_management_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/room_management_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/room_occupancy_calendar_screen.dart';
// import 'package:soko_mtandao/features/explore/presentation/screens/hotel_detail_screen.dart';
import 'package:soko_mtandao/features/splash/splash_screen.dart';
import 'package:soko_mtandao/layouts/admin_layout.dart';
import 'package:soko_mtandao/layouts/app_layout.dart';
import 'package:soko_mtandao/layouts/auth_layout.dart';
import 'package:soko_mtandao/router/redirect_logic.dart';
import 'package:soko_mtandao/router/route_names.dart';
import '../../features/guest_home/presentation/screens/explore_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
// import '../../features/staff_home/presentation/screens/staff_dashboard.dart';
// import '../../features/hotel_admin/presentation/screens/hotel_admin_dashboard.dart';
// import '../../features/system_admin/presentation/screens/system_admin_dashboard.dart';

class AppRouter {
  static GoRouter createRouter(WidgetRef ref) {
    final authNotifier = ref.read(authNotifierProvider);

    final router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: authNotifier,
      routes: [
              // Splash
              GoRoute(path: RouteNames.splash, name: 'splash', builder: (c, s) => const SplashScreen()),

              // Auth layout
              ShellRoute(
                builder: (context, state, child) => AuthLayout(child: child),
                routes: [
                  GoRoute(path: RouteNames.login, name: 'login', builder: (c, s) => const LoginScreen()),
                  GoRoute(path: RouteNames.signup, name: 'signup', builder: (c, s) => const SignupScreen()),
                ],
              ),

              // App layout (guest/customer/staff) — nested ShellRoute with dynamic bottom nav
              ShellRoute(
                builder: (context, state, child) {
                  final selectedIndex = _computeIndex(state.uri.toString(), authNotifier.role);
                  return AppLayout(child: child, selectedIndex: selectedIndex);
                },
                routes: [
                  GoRoute(path: RouteNames.guestHome, name: 'guestHome', builder: (c, s) => const ExploreMapScreen()),
                  GoRoute(path: RouteNames.hotels, name: 'hotels', builder: (c, s) => const HotelSearchScreen()),
                  GoRoute(path: RouteNames.bookings, name: 'bookings', builder: (c, s) => const FindBookingScreen()),
                  GoRoute(path: RouteNames.profile, name: 'profile', redirect: (context, state) {
                    final authNotifier = ref.read(authNotifierProvider);
                    if (!authNotifier.isLoggedIn) {
                      return RouteNames.login;
                    }
                    if (authNotifier.role == UserRole.systemAdmin) {
                      return RouteNames.systemAdminHome;
                    }
                    if (authNotifier.role == UserRole.hotelAdmin) {
                      return RouteNames.hotelAdminHome;
                    }
                    return null;
                  }),
                  GoRoute(path: RouteNames.staffHome, name: 'staffHome', builder: (c, s) => const /* StaffDashboard() */Placeholder()),
                  GoRoute(path: RouteNames.hotelDetail, name: 'hotelDetail', builder: (c, s) {
                    final hotelId = s.pathParameters['hotelId'] ?? '';
                    return HotelDetailScreen(hotelId: hotelId);
                  }),
                  GoRoute(
                    path: RouteNames.bookingInitiate,
                    name: 'bookingInitiate',
                    builder: (c, s) => const UserInfoScreen(),
                  ),
                  GoRoute(
                    path: '${RouteNames.bookingReview}/:id',
                    name: 'bookingReview',
                    builder: (c, s) => BookingReviewScreen(bookingId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: '${RouteNames.payment}/:id',
                    name: 'payment',
                    builder: (c, s) => PaymentScreen(bookingId: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: '${RouteNames.bookingConfirmation}/:id',
                    name: 'bookingConfirmation',
                    builder: (c, s) => BookingConfirmationScreen(bookingId: s.pathParameters['id']!),
                  ),
                  GoRoute(path: RouteNames.requestHotelAssociation, name: 'requestAssociation', builder: (c, s) => const Center(child: Text('Request Association'))),
                ],
              ),

              // Admin layout
              ShellRoute(
                builder: (context, state, child) {
                  final selectedAdminIndex = _computeIndex(state.uri.toString(), authNotifier.role);
                  return AdminLayout(selectedIndex: selectedAdminIndex, child: child,);
                },
                routes: [
                  GoRoute(path: RouteNames.hotelAdminHome, name: 'hotelAdmin', builder: (c, s) => ManagerDashboardScreen()),
                  GoRoute(path: RouteNames.systemAdminHome, name: 'systemAdmin', builder: (c, s) => const /* SystemAdminDashboard() */Placeholder()),
                  GoRoute(
                    path: RouteNames.managerHotel,
                    name: 'hotelPage',
                    builder: (c, s) => ManagerHotelDetailScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                  GoRoute(
                    path: '${RouteNames.hotelList}/:managerUserId',
                    name: 'hotelList',
                    builder: (c, s) => ManagerHotelListScreen(managerUserId: s.pathParameters['managerUserId']!),
                  ),
                  GoRoute(
                    path: RouteNames.addHotel,
                    name: 'addHotel',
                    builder: (c, s) => AddHotelScreen(),
                  ),
                  GoRoute(
                    path: RouteNames.offerings,
                    name: 'offerings',
                    builder: (c, s) => OfferingListScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                  GoRoute(
                    path: RouteNames.addOfferings,
                    name: 'addOfferings',
                    builder: (c, s) => AddOfferingScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                  GoRoute(
                    path: RouteNames.rooms,
                    name: 'rooms',
                    builder: (c, s) => RoomListScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                  GoRoute(
                    path: RouteNames.addRooms,
                    name: 'addRooms',
                    builder: (c, s) => AddRoomScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                  GoRoute(
                    path: RouteNames.roomDetails,
                    name: 'roomDetails',
                    builder: (c, s) => ManagerRoomDetailsPage(roomId: s.pathParameters['roomId']!),
                  ),
                  GoRoute(
                    path: RouteNames.roomBookings,
                    name: 'roomBookings',
                    builder: (c, s) => RoomOccupancyCalendarScreen(roomId: s.pathParameters['roomId']!),
                  ),
                  GoRoute(
                    path: RouteNames.hotelBookings,
                    name: 'hotelBookings',
                    builder: (c, s) => BookingListScreen(hotelId: s.pathParameters['hotelId']!),
                  ),
                ],
              ),
            ],

        redirect: (context, state) {
        // Get concrete auth & role state
        final isLoggedIn = authNotifier.isLoggedIn;
        final role = authNotifier.role;
        final staffAssoc = authNotifier.staffHasHotel;
        final hasRedirectedAfterLogin = authNotifier.hasRedirectedAfterLogin;

        final redirect = globalRedirect(state.uri, isLoggedIn: isLoggedIn, role: role, hasRedirectedAfterLogin: hasRedirectedAfterLogin);

        // Additional: staff without hotel trying to access staffHome -> take them to request page
        if (isLoggedIn && role == UserRole.staff && !staffAssoc && state.uri.toString() == RouteNames.staffHome) {
          return RouteNames.requestHotelAssociation;
        }
        
        if (redirect == RouteNames.hotelAdminHome){
        authNotifier.markRedirectDone();
        }
        return redirect;
      },
      errorBuilder: (context, state) => const Scaffold(body: Center(child: Text('Page not found'))),
    );

    return router;
  }
}

_computeIndex(String location, UserRole role) {
  // compute bottom nav index based on route and role
  if (role == UserRole.customer || role == UserRole.guest) {
    if (location.startsWith(RouteNames.guestHome)) return 0;
    if (location.startsWith(RouteNames.bookings)) return 1;
    if (location.startsWith(RouteNames.profile)) return 2;
  }
  if (role == UserRole.staff) {
    if (location.startsWith(RouteNames.staffHome)) return 0;
    if (location.startsWith(RouteNames.bookings)) return 1;
    if (location.startsWith(RouteNames.profile)) return 2;
  }
  // admin handled by AdminLayout (no bottom nav)
  if (role == UserRole.hotelAdmin){
    if (location.startsWith(RouteNames.guestHome)) return 0;
    if (location.startsWith(RouteNames.profile)) return 1;
    if (location.startsWith(RouteNames.managerHotel)) return 2;
    if (location.startsWith(RouteNames.rooms)) return 3;
    if (location.startsWith(RouteNames.offerings)) return 4;
    if (location.startsWith(RouteNames.hotelBookings)) return 5;
  }
  return 0;
}