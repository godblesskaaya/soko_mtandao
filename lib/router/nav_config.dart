// NavItem model and configuration for bottom navigation per role

import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/constants/roles.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String routeName;
  final List<UserRole> visibleTo;

  const NavItem(
      {required this.label,
      required this.icon,
      required this.routeName,
      required this.visibleTo});
}

final navItems = <NavItem>[
  NavItem(
      label: 'Explore',
      icon: Icons.explore,
      routeName: 'guestHome',
      visibleTo: [UserRole.guest, UserRole.customer]),
  NavItem(
      label: 'Hotels',
      icon: Icons.hotel,
      routeName: 'hotels',
      visibleTo: [UserRole.guest, UserRole.customer]),
  NavItem(
      label: 'Bookings',
      icon: Icons.book,
      routeName: 'bookings',
      visibleTo: [UserRole.guest, UserRole.customer]),
  NavItem(
      label: 'Profile',
      icon: Icons.person,
      routeName: 'profile',
      visibleTo: [UserRole.guest, UserRole.customer]),

  // Staff
  NavItem(
      label: 'Work',
      icon: Icons.dashboard,
      routeName: 'staffHome',
      visibleTo: [UserRole.staff]),
  NavItem(
      label: 'Bookings',
      icon: Icons.book,
      routeName: 'bookings',
      visibleTo: [UserRole.staff]),
  NavItem(
      label: 'Profile',
      icon: Icons.person,
      routeName: 'profile',
      visibleTo: [UserRole.staff]),

  // Hotel Admin
  NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      routeName: 'hotelAdmin',
      visibleTo: [UserRole.hotelAdmin]),
  NavItem(
      label: 'Hotel',
      icon: Icons.hotel,
      routeName: 'myHotel',
      visibleTo: [UserRole.hotelAdmin]),
  NavItem(
      label: 'Offerings',
      icon: Icons.holiday_village,
      routeName: 'offerings',
      visibleTo: [UserRole.hotelAdmin]),
  NavItem(
      label: 'Rooms',
      icon: Icons.room_preferences,
      routeName: 'rooms',
      visibleTo: [UserRole.hotelAdmin]),
  NavItem(
      label: 'Bookings',
      icon: Icons.bookmarks,
      routeName: 'hotelBookings',
      visibleTo: [UserRole.hotelAdmin]),

  // System Admin
  NavItem(
      label: 'Admin',
      icon: Icons.admin_panel_settings,
      routeName: 'systemAdmin',
      visibleTo: [UserRole.systemAdmin]),
];
