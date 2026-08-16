import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/constants/roles.dart';

void main() {
  group('roleFromString', () {
    test('normalizes supported role spellings', () {
      expect(roleFromString('customer'), UserRole.customer);
      expect(roleFromString('staff'), UserRole.staff);
      expect(roleFromString('hotel_admin'), UserRole.hotelAdmin);
      expect(roleFromString('hotelAdmin'), UserRole.hotelAdmin);
      expect(roleFromString('Hotel Admin'), UserRole.hotelAdmin);
      expect(roleFromString('system_admin'), UserRole.systemAdmin);
      expect(roleFromString('systemAdmin'), UserRole.systemAdmin);
      expect(roleFromString('systemadmin'), UserRole.systemAdmin);
      expect(roleFromString('System Admin'), UserRole.systemAdmin);
    });
  });
}
