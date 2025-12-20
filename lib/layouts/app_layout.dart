import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/widgets/dynamic_bottom_nav.dart';
import '../router/nav_config.dart';

/// AppLayout: used for guest/customer/staff main flows. Contains a dynamic BottomNav
class AppLayout extends ConsumerWidget {
  final Widget child;
  final int selectedIndex;
  const AppLayout({super.key, required this.child, required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = navItems.where((i) {
      final authNotifier = ref.watch(authNotifierProvider);
      final role = authNotifier.role;
      return i.visibleTo.contains(role);
    }).toList();

    return Scaffold(
      body: child,
      bottomNavigationBar: DynamicBottomNav(
        items: items,
        selectedIndex: selectedIndex,
        onTap: (idx) {
          final routeName = items[idx].routeName;
          // Navigate using named route
          context.pushNamed(routeName);
        },
      ),
    );
  }
}

// class _AppLayoutState extends ConsumerState<AppLayout> {
//   late int _selectedIndex;

//   @override
//   void initState() {
//     super.initState();
//     _selectedIndex = widget.selectedIndex;
//   }

//   void _onItemTapped(int index, String routeName) {
//     setState(() => _selectedIndex = index);
//     // Navigate using named route
//     context.pushNamed(routeName);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final authNotifier = ref.watch(authNotifierProvider);
//     final role = authNotifier.role;

//     // final items = roleAsync.maybeWhen(
//     //   data: (role) => navItems.where((i) => i.visibleTo.contains(role)).toList(),
//     //   orElse: () => navItems.where((i) => i.visibleTo.contains(UserRole.guest)).toList(),
//     // );

//     final items = navItems.where((i) {
//       return i.visibleTo.contains(role);
//     }).toList();

//     // Ensure selected index is within bounds
//     if (_selectedIndex < 0 || _selectedIndex >= navItems.length) {
//         _selectedIndex = 0; // Default to first item if out of bounds
//       }

//     return Scaffold(
//       body: widget.child,
//       bottomNavigationBar: DynamicBottomNav(
//         items: items,
//         selectedIndex: _selectedIndex,
//         onTap: (idx) => _onItemTapped(idx, items[idx].routeName),
//       ),
//     );
//   }
// }