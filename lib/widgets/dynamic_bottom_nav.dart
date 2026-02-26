import 'package:flutter/material.dart';
import '../router/nav_config.dart';

class DynamicBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const DynamicBottomNav(
      {super.key,
      required this.items,
      required this.selectedIndex,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTap,
      items: items
          .map((i) => BottomNavigationBarItem(
                icon: Icon(i.icon),
                label: i.label,
              ))
          .toList(),
    );
  }
}
