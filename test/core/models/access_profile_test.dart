import 'package:flutter_test/flutter_test.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/models/access_profile.dart';

void main() {
  group('AccessProfile', () {
    test('guest factory returns a guest-safe profile', () {
      final profile = AccessProfile.guest();

      expect(profile.activePersona, UserRole.guest);
      expect(profile.availablePersonas, isEmpty);
      expect(profile.needsInitialPathSelection, isTrue);
      expect(profile.hasActiveOperatorOnboarding, isFalse);
      expect(profile.onboardingSummary, 'Choose how you want to use the app');
    });

    test('fromJson deduplicates roles and maps access flags', () {
      final profile = AccessProfile.fromJson({
        'active_persona': 'hotel_admin',
        'roles': ['customer', 'hotel_admin', 'customer', 'staff'],
        'selected_onboarding_path': 'manage_hotel',
        'onboarding_status': 'in_progress',
        'onboarding_step': 'kyc',
        'has_seen_onboarding': true,
        'staff_association_status': 'accepted',
        'manager_application_status': 'approved',
        'kyc_status': 'approved',
        'managed_hotel_count': 2,
      });

      expect(profile.activePersona, UserRole.hotelAdmin);
      expect(
        profile.availablePersonas,
        [UserRole.customer, UserRole.hotelAdmin, UserRole.staff],
      );
      expect(profile.hasMultiplePersonas, isTrue);
      expect(profile.canUseHotelAdminPersona, isTrue);
      expect(profile.canUseStaffPersona, isTrue);
      expect(profile.needsInitialPathSelection, isFalse);
      expect(profile.onboardingSummary, 'Approved for hotel management');
    });

    test('pending staff onboarding blocks staff persona access', () {
      final profile = AccessProfile.fromJson({
        'active_persona': 'customer',
        'roles': ['customer', 'staff'],
        'selected_onboarding_path': 'join_team',
        'onboarding_status': 'in_progress',
        'onboarding_step': 'association',
        'has_seen_onboarding': true,
        'staff_association_status': 'pending',
        'manager_application_status': 'none',
        'kyc_status': 'pending',
        'managed_hotel_count': 0,
      });

      expect(profile.isStaffPending, isTrue);
      expect(profile.canUseStaffPersona, isFalse);
      expect(profile.hasActiveOperatorOnboarding, isTrue);
      expect(profile.onboardingSummary, 'Staff request pending review');
    });

    test('rejected manager application is surfaced clearly', () {
      final profile = AccessProfile.fromJson({
        'active_persona': 'customer',
        'roles': ['customer'],
        'selected_onboarding_path': 'manage_hotel',
        'onboarding_status': 'in_progress',
        'onboarding_step': 'review',
        'has_seen_onboarding': true,
        'staff_association_status': 'none',
        'manager_application_status': 'rejected',
        'kyc_status': 'approved',
        'managed_hotel_count': 0,
      });

      expect(profile.isManagerRejected, isTrue);
      expect(profile.canUseHotelAdminPersona, isFalse);
      expect(profile.hasActiveOperatorOnboarding, isTrue);
      expect(profile.onboardingSummary, 'Manager application needs updates');
    });
  });
}
