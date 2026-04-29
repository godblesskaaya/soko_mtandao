import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';

class OnboardingHubScreen extends ConsumerWidget {
  const OnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessProfile = ref.watch(authNotifierProvider).accessProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Path')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your account keeps normal customer access while we set up any operator tools.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _PathCard(
            icon: Icons.bed_outlined,
            title: 'Book stays',
            subtitle:
                'Use Soko Mtandao as a customer right away. You can still apply for operator access later.',
            ctaLabel: 'Continue as Customer',
            onTap: () async {
              await ref.read(authNotifierProvider).chooseOnboardingPath('customer');
              if (context.mounted) context.go(RouteNames.guestHome);
            },
          ),
          const SizedBox(height: 12),
          _PathCard(
            icon: Icons.business_center_outlined,
            title: 'Manage a hotel',
            subtitle: accessProfile.managerApplicationStatus == 'approved'
                ? 'Your manager access is approved. Open the manager workspace or refine your application details.'
                : 'Complete your profile, KYC, and first property details before sending an application for review.',
            ctaLabel: accessProfile.managerApplicationStatus == 'approved'
                ? 'Open Manager Workspace'
                : 'Start Manager Onboarding',
            onTap: () async {
              await ref
                  .read(authNotifierProvider)
                  .chooseOnboardingPath('manage_hotel');
              if (!context.mounted) return;
              if (accessProfile.canUseHotelAdminPersona) {
                await ref
                    .read(authNotifierProvider)
                    .setActivePersona(UserRole.hotelAdmin);
                if (!context.mounted) return;
                context.go(RouteNames.hotelAdminHome);
              } else {
                context.push(RouteNames.managerOnboarding);
              }
            },
          ),
          const SizedBox(height: 12),
          _PathCard(
            icon: Icons.groups_outlined,
            title: 'Join a hotel team',
            subtitle: accessProfile.staffAssociationStatus == 'accepted'
                ? 'Your staff access is active. You can switch into the staff workspace whenever needed.'
                : 'Enter an invite token or request to join a hotel team. You stay in customer mode while approval is pending.',
            ctaLabel: accessProfile.staffAssociationStatus == 'accepted'
                ? 'Open Staff Workspace'
                : 'Start Staff Onboarding',
            onTap: () async {
              await ref.read(authNotifierProvider).chooseOnboardingPath('join_team');
              if (!context.mounted) return;
              if (accessProfile.canUseStaffPersona) {
                await ref
                    .read(authNotifierProvider)
                    .setActivePersona(UserRole.staff);
                if (!context.mounted) return;
                context.go(RouteNames.staffHome);
              } else {
                context.push(RouteNames.staffOnboarding);
              }
            },
          ),
          const SizedBox(height: 24),
          if (accessProfile.hasActiveOperatorOnboarding)
            OutlinedButton.icon(
              onPressed: () => context.push(RouteNames.pendingAccess),
              icon: const Icon(Icons.pending_actions_outlined),
              label: const Text('View Pending Access Status'),
            ),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton(onPressed: onTap, child: Text(ctaLabel)),
          ],
        ),
      ),
    );
  }
}
