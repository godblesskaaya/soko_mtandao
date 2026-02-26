// go_router configuration with ShellRoutes for layouts, named routes, and redirect

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:soko_mtandao/features/auth/presentation/screens/reset_password_screen.dart';
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
import 'package:soko_mtandao/features/management/presentation/screens/manager_booking_detail_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_notifications_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_payments_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_profile_edit_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_room_details_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/manager_settings_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/offering_management_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/room_management_screen.dart';
import 'package:soko_mtandao/features/management/presentation/screens/room_occupancy_calendar_screen.dart';
import 'package:soko_mtandao/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:soko_mtandao/features/settings/presentation/screens/profile_screen.dart';
import 'package:soko_mtandao/features/staff/presentation/screens/request_association_screen.dart';
import 'package:soko_mtandao/features/staff/presentation/screens/staff_home_screen.dart';
import 'package:soko_mtandao/features/splash/splash_screen.dart';
import 'package:soko_mtandao/features/system_admin/presentation/screens/system_admin_dashboard_screen.dart';
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
    final analytics = ref.read(analyticsServiceProvider);
    void trackManagerScreen(String route) {
      analytics.track('manager_target_screen_loaded', params: {'route': route});
    }

    final router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: authNotifier,
      routes: [
        // Splash
        GoRoute(
            path: RouteNames.splash,
            name: 'splash',
            builder: (c, s) => const SplashScreen()),
        GoRoute(
            path: RouteNames.deleteAccount,
            name: 'deleteAccount',
            builder: (c, s) {
              final isManagerStr = s.pathParameters['isManager'] ?? 'false';
              final isManager = isManagerStr.toLowerCase() == 'true';
              return DeleteAccountScreen(isManager: isManager);
            }),

        // Auth layout
        ShellRoute(
          builder: (context, state, child) => AuthLayout(child: child),
          routes: [
            GoRoute(
                path: RouteNames.login,
                name: 'login',
                builder: (c, s) => const LoginScreen()),
            GoRoute(
                path: RouteNames.signup,
                name: 'signup',
                builder: (c, s) => const SignupScreen()),
            GoRoute(
                path: RouteNames.resetPassword,
                name: 'resetPassword',
                builder: (c, s) => const ResetPasswordScreen()),
            GoRoute(
                path: RouteNames.forgotPassword,
                name: 'forgotPassword',
                builder: (c, s) => const ForgotPasswordScreen()),
          ],
        ),

        // App layout (guest/customer/staff) — nested ShellRoute with dynamic bottom nav
        ShellRoute(
          builder: (context, state, child) {
            final selectedIndex =
                _computeIndex(state.uri.path, authNotifier.role);
            return AppLayout(child: child, selectedIndex: selectedIndex);
          },
          routes: [
            GoRoute(
                path: RouteNames.guestHome,
                name: 'guestHome',
                builder: (c, s) => const ExploreMapScreen()),
            GoRoute(
                path: RouteNames.hotels,
                name: 'hotels',
                builder: (c, s) => const HotelSearchScreen()),
            GoRoute(
                path: RouteNames.bookings,
                name: 'bookings',
                builder: (c, s) => const FindBookingScreen()),
            GoRoute(
              path: RouteNames.profile,
              name: 'profile',
              builder: (c, s) => const ProfileScreen(),
              redirect: (context, state) {
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
              },
            ),
            GoRoute(
                path: RouteNames.staffHome,
                name: 'staffHome',
                builder: (c, s) => const StaffHomeScreen()),
            GoRoute(
                path: RouteNames.hotelDetail,
                name: 'hotelDetail',
                builder: (c, s) {
                  final hotelId = s.pathParameters['hotelId'] ?? '';
                  final checkIn =
                      DateTime.tryParse(s.uri.queryParameters['checkIn'] ?? '');
                  final checkOut = DateTime.tryParse(
                      s.uri.queryParameters['checkOut'] ?? '');
                  return HotelDetailScreen(
                    hotelId: hotelId,
                    initialCheckIn: checkIn,
                    initialCheckOut: checkOut,
                  );
                }),
            GoRoute(
              path: RouteNames.bookingInitiate,
              name: 'bookingInitiate',
              builder: (c, s) => const UserInfoScreen(),
            ),
            GoRoute(
              path: '${RouteNames.bookingReview}/:id',
              name: 'bookingReview',
              builder: (c, s) =>
                  BookingReviewScreen(bookingId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '${RouteNames.payment}/:id',
              name: 'payment',
              builder: (c, s) =>
                  PaymentScreen(bookingId: s.pathParameters['id']!),
            ),
            GoRoute(
              path: '${RouteNames.bookingConfirmation}/:id',
              name: 'bookingConfirmation',
              builder: (c, s) =>
                  BookingConfirmationScreen(bookingId: s.pathParameters['id']!),
            ),
            GoRoute(
                path: RouteNames.requestHotelAssociation,
                name: 'requestAssociation',
                builder: (c, s) => const RequestAssociationScreen()),
          ],
        ),

        // Admin layout
        ShellRoute(
          builder: (context, state, child) {
            final selectedAdminIndex =
                _computeIndex(state.uri.path, authNotifier.role);
            return AdminLayout(
              selectedIndex: selectedAdminIndex,
              child: child,
            );
          },
          routes: [
            GoRoute(
                path: RouteNames.hotelAdminHome,
                name: 'hotelAdmin',
                builder: (c, s) {
                  trackManagerScreen('hotelAdmin');
                  return ManagerDashboardScreen();
                }),
            GoRoute(
                path: RouteNames.systemAdminHome,
                name: 'systemAdmin',
                builder: (c, s) => const SystemAdminDashboardScreen()),
            GoRoute(
              path: RouteNames.managerHotel,
              name: 'hotelPage',
              builder: (c, s) {
                trackManagerScreen('hotelPage');
                return ManagerHotelDetailScreen(
                    hotelId: s.pathParameters['hotelId']!);
              },
            ),
            GoRoute(
              path: '${RouteNames.hotelList}/:managerUserId',
              name: 'hotelList',
              builder: (c, s) {
                trackManagerScreen('hotelList');
                return ManagerHotelListScreen(
                    managerUserId: s.pathParameters['managerUserId']!);
              },
            ),
            GoRoute(
              path: RouteNames.addHotel,
              name: 'addHotel',
              builder: (c, s) {
                trackManagerScreen('addHotel');
                return AddHotelScreen();
              },
            ),
            GoRoute(
              path: RouteNames.offerings,
              name: 'offerings',
              builder: (c, s) {
                trackManagerScreen('offerings');
                return OfferingListScreen(
                    hotelId: s.pathParameters['hotelId']!);
              },
            ),
            GoRoute(
              path: RouteNames.addOfferings,
              name: 'addOfferings',
              builder: (c, s) =>
                  OfferingScreen(hotelId: s.pathParameters['hotelId']!),
            ),
            GoRoute(
              path: RouteNames.rooms,
              name: 'rooms',
              builder: (c, s) {
                trackManagerScreen('rooms');
                return RoomListScreen(hotelId: s.pathParameters['hotelId']!);
              },
            ),
            GoRoute(
              path: RouteNames.addRooms,
              name: 'addRooms',
              builder: (c, s) =>
                  RoomScreen(hotelId: s.pathParameters['hotelId']!),
            ),
            GoRoute(
              path: RouteNames.editOffering,
              name: 'editOffering',
              builder: (c, s) => OfferingScreen(
                hotelId: s.pathParameters['hotelId']!,
                offeringId: s.pathParameters['offeringId']!,
              ),
            ),
            GoRoute(
              path: RouteNames.editRoom,
              name: 'editRoom',
              builder: (c, s) => RoomScreen(
                hotelId: s.pathParameters['hotelId']!,
                roomId: s.pathParameters['roomId']!,
              ),
            ),
            GoRoute(
              path: RouteNames.roomDetails,
              name: 'roomDetails',
              builder: (c, s) =>
                  ManagerRoomDetailsPage(roomId: s.pathParameters['roomId']!),
            ),
            GoRoute(
              path: RouteNames.roomBookings,
              name: 'roomBookings',
              builder: (c, s) => RoomOccupancyCalendarScreen(
                  roomId: s.pathParameters['roomId']!),
            ),
            GoRoute(
              path: RouteNames.hotelBookings,
              name: 'hotelBookings',
              builder: (c, s) {
                trackManagerScreen('hotelBookings');
                return BookingListScreen(hotelId: s.pathParameters['hotelId']!);
              },
            ),
            GoRoute(
              path: RouteNames.managerPayments,
              name: 'managerPayments',
              builder: (c, s) {
                trackManagerScreen('managerPayments');
                return ManagerPaymentsScreen(
                    hotelId: s.pathParameters['hotelId']!);
              },
            ),
            GoRoute(
              path: RouteNames.editHotel,
              name: 'editHotel',
              builder: (c, s) =>
                  AddHotelScreen(hotelId: s.pathParameters['hotelId']!),
            ),
            GoRoute(
              path: RouteNames.settings,
              name: 'settings',
              builder: (c, s) {
                trackManagerScreen('settings');
                return const ManagerSettingsScreen();
              },
            ),
            GoRoute(
              path: RouteNames.managerNotifications,
              name: 'notifications',
              builder: (c, s) {
                trackManagerScreen('notifications');
                return const ManagerNotificationsScreen();
              },
            ),
            GoRoute(
              path: RouteNames.editManagerProfile,
              name: 'editManagerProfile',
              builder: (c, s) {
                trackManagerScreen('editManagerProfile');
                return const ManagerProfileEditScreen();
              },
            ),
            GoRoute(
              path: RouteNames.managerBookingDetail,
              name: 'managerBookingDetail',
              builder: (c, s) {
                trackManagerScreen('managerBookingDetail');
                return ManagerBookingDetailScreen(
                  bookingId: s.pathParameters['bookingId']!,
                );
              },
            ),
          ],
        ),
      ],
      redirect: (context, state) {
        // Get concrete auth & role state
        final isLoggedIn = authNotifier.isLoggedIn;
        final role = authNotifier.role;
        final isInPasswordRecovery = authNotifier.isInPasswordRecovery;
        final staffAssoc = authNotifier.staffHasHotel;
        final hasRedirectedAfterLogin = authNotifier.hasRedirectedAfterLogin;

        final redirect = globalRedirect(state.uri,
            isLoggedIn: isLoggedIn,
            role: role,
            isInPasswordRecovery: isInPasswordRecovery,
            hasRedirectedAfterLogin: hasRedirectedAfterLogin);

        // Additional: staff without hotel trying to access staffHome -> take them to request page
        if (isLoggedIn &&
            role == UserRole.staff &&
            !staffAssoc &&
            state.uri.toString() == RouteNames.staffHome) {
          return RouteNames.requestHotelAssociation;
        }

        if (redirect == RouteNames.hotelAdminHome) {
          authNotifier.markRedirectDone();
        }
        return redirect;
      },
      errorBuilder: (context, state) {
        analytics
            .track('route_not_found', params: {'path': state.uri.toString()});
        return const Scaffold(body: Center(child: Text('Page not found')));
      },
    );

    return router;
  }
}

_computeIndex(String location, UserRole role) {
  bool matchesPath(String template) {
    final staticPrefix = template.split('/:').first;
    return location == staticPrefix || location.startsWith('$staticPrefix/');
  }

  // compute bottom nav index based on route and role
  if (role == UserRole.customer || role == UserRole.guest) {
    if (location.startsWith(RouteNames.guestHome)) return 0;
    if (location.startsWith(RouteNames.hotels)) return 1;
    if (location.startsWith(RouteNames.bookings)) return 2;
    if (location.startsWith(RouteNames.profile)) return 3;
  }
  if (role == UserRole.staff) {
    if (location.startsWith(RouteNames.staffHome)) return 0;
    if (location.startsWith(RouteNames.bookings)) return 1;
    if (location.startsWith(RouteNames.profile)) return 2;
  }
  if (role == UserRole.systemAdmin) {
    if (location.startsWith(RouteNames.systemAdminHome)) return 0;
  }

  if (role == UserRole.hotelAdmin) {
    if (location.startsWith(RouteNames.hotelAdminHome)) return 0;
    if (matchesPath(RouteNames.managerHotel) ||
        matchesPath(RouteNames.editHotel)) return 1;
    if (matchesPath(RouteNames.offerings) ||
        matchesPath(RouteNames.editOffering) ||
        matchesPath(RouteNames.addOfferings)) return 2;
    if (matchesPath(RouteNames.rooms) ||
        matchesPath(RouteNames.editRoom) ||
        matchesPath(RouteNames.addRooms)) return 3;
    if (matchesPath(RouteNames.hotelBookings) ||
        matchesPath(RouteNames.managerPayments) ||
        matchesPath(RouteNames.managerBookingDetail)) return 4;
  }
  return 0;
}
