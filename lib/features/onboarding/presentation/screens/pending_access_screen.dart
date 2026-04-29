import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class PendingAccessScreen extends ConsumerWidget {
  const PendingAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessProfile = ref.watch(authNotifierProvider).accessProfile;

    String title = 'Choose how you want to use the app';
    String subtitle =
        'Pick a path to keep exploring as a customer or start operator onboarding.';
    String actionLabel = 'Open onboarding hub';
    VoidCallback action = () => context.go(RouteNames.onboardingHub);

    if (accessProfile.selectedPath == 'manage_hotel') {
      title = 'Manager access is in progress';
      if (accessProfile.managerApplicationStatus == 'rejected') {
        subtitle =
            'Your manager application needs updates. Review your profile, KYC, and property details before submitting again.';
        actionLabel = 'Update manager application';
        action = () => context.go(RouteNames.managerOnboarding);
      } else if (accessProfile.managerApplicationStatus == 'approved') {
        title = 'Manager access is approved';
        subtitle =
            'Switch to the Hotel Admin persona from your profile or open the manager workspace directly.';
        actionLabel = 'Open manager workspace';
        action = () async {
          await ref.read(authNotifierProvider).setActivePersona(UserRole.hotelAdmin);
          if (context.mounted) {
            context.go(RouteNames.hotelAdminHome);
          }
        };
      } else {
        subtitle =
            'Your application is saved and waiting for review. You can still explore and book as a customer in the meantime.';
        actionLabel = 'View manager application';
        action = () => context.go(RouteNames.managerOnboarding);
      }
    } else if (accessProfile.selectedPath == 'join_team') {
      title = 'Staff access is in progress';
      if (accessProfile.staffAssociationStatus == 'rejected') {
        subtitle =
            'Your team request was rejected. You can try another hotel or accept a fresh invite token.';
        actionLabel = 'Update staff onboarding';
        action = () => context.go(RouteNames.staffOnboarding);
      } else if (accessProfile.staffAssociationStatus == 'accepted') {
        title = 'Staff access is approved';
        subtitle =
            'Switch to your Staff persona from your profile or head to the staff workspace now.';
        actionLabel = 'Open staff workspace';
        action = () async {
          await ref.read(authNotifierProvider).setActivePersona(UserRole.staff);
          if (context.mounted) {
            context.go(RouteNames.staffHome);
          }
        };
      } else {
        subtitle =
            'Your hotel team access is pending approval. Customer browsing and bookings stay available.';
        actionLabel = 'View staff onboarding';
        action = () => context.go(RouteNames.staffOnboarding);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Access')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppStateView.empty(
            title: title,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onAction: action,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.go(RouteNames.guestHome),
            icon: const Icon(Icons.travel_explore_outlined),
            label: const Text('Continue as Customer'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(RouteNames.profile),
            icon: const Icon(Icons.person_outline),
            label: const Text('Open Profile'),
          ),
        ],
      ),
    );
  }
}
