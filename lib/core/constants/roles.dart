// lib/core/constants/roles.dart
enum UserRole {
  guest,
  customer,
  staff,
  hotelAdmin,
  systemAdmin,
}

UserRole roleFromString(String role) {
  switch (role) {
    case 'customer':
      return UserRole.customer;
    case 'staff':
      return UserRole.staff;
    case 'hotel_admin':
    case 'hotelAdmin':
      return UserRole.hotelAdmin;
    case 'system_admin':
    case 'systemAdmin':
      return UserRole.systemAdmin;
    default:
      return UserRole.guest;
  }
}
