import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_hotel.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';
import 'package:soko_mtandao/router/nav_config.dart';
import 'package:soko_mtandao/widgets/dynamic_bottom_nav.dart';
import 'package:soko_mtandao/widgets/entity_picker.dart';

/// AdminLayout: layout for admin pages (hotel admin & system admin)
class AdminLayout extends ConsumerWidget {
  final Widget child;
  
  final int selectedIndex;
  const AdminLayout({super.key, required this.child, required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref){
    final items = navItems.where((i) {
      return i.visibleTo.contains(UserRole.hotelAdmin);
    }).toList();

    return Scaffold(
      // extendBody: true,
      body: SafeArea(
        top: false,
        bottom: true,
        child: child,
      ),
      bottomNavigationBar: DynamicBottomNav(
        items: items,
        selectedIndex: selectedIndex,
        onTap: (idx) => _onItemTapped(context, idx, items[idx].routeName, ref),
      ),
    );
  }

  // void _onItemTapped(int index, String routeName){
  //   setState(() => _selectedIndex = index);
  //   // if route is named room,hotel,booking,offerings, call modal for selecting hotel and pass the route name
  //   if (routeName == 'room' || routeName == 'hotel' || routeName == 'booking' || routeName == 'offerings') {
  //     _showHotelSelectionModal(routeName);
  //   } else {
  //     // navigate using named route
  //     context.pushNamed(routeName);
  //   }
  // }
  Future<List<ManagerHotel>> _fetchHotelsFromRepo(WidgetRef ref) async {
    final AuthService authService = AuthService();
    final managerUserId = authService.currentUser?.id;
    if (managerUserId == null || managerUserId.isEmpty) return [];
  // Use ref to access repo/provider
  final hotelsAsync = ref.watch(managerHotelsProvider(managerUserId));

  return hotelsAsync.when(
    data: (hotels) => hotels,
    loading: () => [],
    error: (err, _) => [],
  );
}
  void _onItemTapped(BuildContext context, int , String routeName, WidgetRef ref) async {
  final needsParam = {'rooms', 'myHotel', 'hotelBookings', 'offerings'}.contains(routeName);

  if (needsParam) {
    final selectedHotel = await showEntityPicker<ManagerHotel>(
      context: context,
      title: 'Choose a Hotel',
      fetchItems: () => _fetchHotelsFromRepo(ref),
      display: (h) => h.name,
    );

    if (selectedHotel == null) return;

    // Navigate with hotelId param (adjust for your route names)
    if (routeName == 'rooms') {
      context.goNamed('rooms', pathParameters: {'hotelId': selectedHotel.id});
    } else if (routeName == 'offerings') {
      context.goNamed('offerings', pathParameters: {'hotelId': selectedHotel.id});
    } else if (routeName == 'hotelBookings') {
      context.goNamed('hotelBookings', pathParameters: {'hotelId': selectedHotel.id});
    } else if (routeName == 'myHotel') {
      context.goNamed('hotelPage', pathParameters: {'hotelId': selectedHotel.id});
    }
    // add other cases as needed
  } else {
    context.goNamed(routeName);
  }
}
}
