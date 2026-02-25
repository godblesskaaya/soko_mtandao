import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';
import 'package:soko_mtandao/widgets/app_web_view.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _brandBlue = Color.fromARGB(255, 6, 101, 153);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider);
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;
    final role = authNotifier.role;

    final fullName = _resolveDisplayName(user?.userMetadata);
    final email = user?.email ?? '';
    final roleLabel = _roleLabel(role);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                        Text('Role: $roleLabel'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Security',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Reset Password'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.pushNamed('forgotPassword'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Data',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppWebViewScreen(
                    title: "Privacy Policy",
                    url: 'https://sites.google.com/view/sokomtandaocompany-privacy',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.pushNamed(
              'deleteAccount',
              pathParameters: {'isManager': 'false'},
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

  String _roleLabel(UserRole role) {
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
}
