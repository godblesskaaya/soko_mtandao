import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/core/constants/app_colors.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:soko_mtandao/widgets/app_section_header.dart';
import 'package:soko_mtandao/widgets/app_web_view.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _brandBlue = AppColors.brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider);
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final profile = authNotifier.accessProfile;

    final fullName = _resolveDisplayName(user?.userMetadata);
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [PersonaSwitcherButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _brandBlue,
                    child: Text(
                      (fullName.isEmpty ? '?' : fullName[0]).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? 'User' : fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(email),
                        const SizedBox(height: 4),
                        Text(
                            'Active persona: ${roleLabel(profile.activePersona)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.availablePersonas
                        .map(
                          (persona) => Chip(
                            avatar: Icon(
                              persona == profile.activePersona
                                  ? Icons.check_circle
                                  : Icons.person_outline,
                              size: 16,
                            ),
                            label: Text(roleLabel(persona)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  Text(profile.onboardingSummary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (profile.selectedPath == 'manage_hotel' ||
              profile.selectedPath == 'join_team')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operator onboarding',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Path: ${_pathLabel(profile.selectedPath)}'),
                    Text('Onboarding status: ${profile.onboardingStatus}'),
                    Text('Current step: ${profile.onboardingStep}'),
                    if (profile.selectedPath == 'manage_hotel')
                      Text(
                          'Manager application: ${profile.managerApplicationStatus} | KYC: ${profile.kycStatus}'),
                    if (profile.selectedPath == 'join_team')
                      Text(
                          'Staff association: ${profile.staffAssociationStatus}'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(RouteNames.onboardingHub),
                          icon: const Icon(Icons.alt_route_outlined),
                          label: const Text('Change Path'),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.push(
                            profile.selectedPath == 'manage_hotel'
                                ? RouteNames.managerOnboarding
                                : RouteNames.staffOnboarding,
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue Onboarding'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Security'),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Reset Password'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.pushNamed('forgotPassword'),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(title: 'Data Controls'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppWebViewScreen(
                    title: 'Privacy Policy',
                    url: AppConfig.privacyPolicyUrl,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms & Conditions'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push(RouteNames.termsAndConditions),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Onboarding Hub'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push(RouteNames.onboardingHub),
          ),
          ListTile(
            leading: const Icon(Icons.pending_actions_outlined),
            title: const Text('Pending Access Status'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push(RouteNames.pendingAccess),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Data Controls',
                style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.pushNamed(
              'deleteAccount',
              pathParameters: {
                'isManager':
                    (profile.activePersona == UserRole.hotelAdmin).toString(),
              },
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider).signOut();
              if (context.mounted) context.goNamed('login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('LOGOUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveDisplayName(Map<String, dynamic>? metadata) {
    if (metadata == null) return '';
    final fullName = (metadata['fullName'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;

    final firstName = (metadata['firstName'] ?? '').toString().trim();
    final lastName = (metadata['lastName'] ?? '').toString().trim();
    return '$firstName $lastName'.trim();
  }

  String _pathLabel(String? path) {
    switch (path) {
      case 'manage_hotel':
        return 'Manage a hotel';
      case 'join_team':
        return 'Join a hotel team';
      case 'customer':
        return 'Book stays';
      default:
        return 'Not selected';
    }
  }
}
