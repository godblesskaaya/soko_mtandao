import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/core/constants/app_colors.dart';
import 'package:soko_mtandao/core/services/auth_service.dart';
import 'package:soko_mtandao/router/route_names.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';
import 'package:soko_mtandao/widgets/app_web_view.dart';
import 'package:soko_mtandao/widgets/app_section_header.dart';

class ManagerSettingsScreen extends ConsumerWidget {
  const ManagerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const brandBlue = AppColors.brand;
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Management Settings'),
        centerTitle: true,
        actions: const [PersonaSwitcherButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Manager Profile Summary
            const CircleAvatar(
              radius: 40,
              backgroundColor: brandBlue,
              child: Icon(Icons.business_center, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 10),
            const Text("Property Manager",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 30),

            // Settings Group: Security
            const AppSectionHeader(title: "Security & Access"),
            _buildSettingItem(
              icon: Icons.vpn_key_outlined,
              title: "Change Password",
              onTap: () => context.pushNamed('forgotPassword'),
            ),

            // Settings Group: Data
            const AppSectionHeader(title: "Data Management"),
            _buildSettingItem(
              icon: Icons.verified_user_outlined,
              title: "KYC Compliance",
              onTap: () => context.pushNamed('managerKyc'),
            ),
            _buildSettingItem(
              icon: Icons.groups_outlined,
              title: "Team Access",
              onTap: () => context.pushNamed('managerTeam'),
            ),
            _buildSettingItem(
              icon: Icons.description_outlined,
              title: "Privacy Policy",
              onTap: () {
                // Navigate to WebView widget
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppWebViewScreen(
                      title: "Privacy Policy",
                      url: AppConfig.privacyPolicyUrl,
                    ),
                  ),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.gavel_outlined,
              title: "Terms & Conditions",
              onTap: () => context.push(RouteNames.termsAndConditions),
            ),
            _buildSettingItem(
              icon: Icons.delete_outline,
              title: "Delete Manager Account",
              titleColor: Colors.red,
              onTap: () => context.pushNamed('deleteAccount',
                  pathParameters: {'isManager': 'true'}),
            ),

            const SizedBox(height: 40),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await authService.signOut();
                    if (context.mounted) context.goNamed('login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("LOGOUT"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? titleColor}) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.brand),
      title: Text(title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
