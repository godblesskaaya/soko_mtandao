// lib/core/constants/roles.dart
enum UserRole {
  guest,
  customer,
  staff,
  hotelAdmin,
  systemAdmin,
}

UserRole roleFromString(String role) {
  final normalized = role.trim().toLowerCase().replaceAll(
        RegExp(r'[\s_-]+'),
        '',
      );

  switch (normalized) {
    case 'customer':
      return UserRole.customer;
    case 'staff':
      return UserRole.staff;
    case 'hoteladmin':
      return UserRole.hotelAdmin;
    case 'systemadmin':
      return UserRole.systemAdmin;
    default:
      return UserRole.guest;
  }
}

String roleToStorageString(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return 'customer';
    case UserRole.staff:
      return 'staff';
    case UserRole.hotelAdmin:
      return 'hotel_admin';
    case UserRole.systemAdmin:
      return 'system_admin';
    case UserRole.guest:
      return 'guest';
  }
}

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return 'Customer';
    case UserRole.staff:
      return 'Staff';
    case UserRole.hotelAdmin:
      return 'Hotel Admin';
    case UserRole.systemAdmin:
      return 'System Admin';
    case UserRole.guest:
      return 'Guest';
  }
}
