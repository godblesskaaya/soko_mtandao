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
class AdminLayout extends ConsumerStatefulWidget {
  final Widget child;
  
  final int selectedIndex;
  const AdminLayout({super.key, required this.child, this.selectedIndex = 0});

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  late int _selectedIndex;
  final AuthService authService = AuthService();

  @override
  void initState(){
    super.initState();
    _selectedIndex = widget.selectedIndex;
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
  void _onItemTapped(int index, String routeName, WidgetRef ref) async {
  setState(() => _selectedIndex = index);

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
      context.goNamed('myHotel', pathParameters: {'hotelId': selectedHotel.id});
    }
    // add other cases as needed
  } else {
    context.goNamed(routeName);
  }
}

  @override
  Widget build(BuildContext context) {
    final items = navItems.where((i) {
      return i.visibleTo.contains(UserRole.hotelAdmin);
    }).toList();

    // Ensure selected index is within bounds
    if (_selectedIndex < 0 || _selectedIndex >= navItems.length) {
      _selectedIndex = 0; // default to first item
    }

    return Scaffold(
      // extendBody: true,
      body: SafeArea(
        top: false,
        bottom: true,
        child: widget.child,
      ),
      bottomNavigationBar: DynamicBottomNav(
        items: items,
        selectedIndex: _selectedIndex,
        onTap: (idx) => _onItemTapped(idx, items[idx].routeName, ref),
      ),
    );
  }
}
