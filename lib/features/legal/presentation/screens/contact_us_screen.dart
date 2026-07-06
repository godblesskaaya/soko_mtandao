import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/core/constants/app_colors.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Contact Soko Mtandao',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use these contacts for general support, account help, hotel onboarding, bookings, payments, and other platform questions.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _ContactCard(
            icon: Icons.email_outlined,
            title: 'Email',
            value: AppConfig.supportEmail,
          ),
          _ContactCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: AppConfig.supportPhone,
          ),
          _ContactCard(
            icon: Icons.location_on_outlined,
            title: 'Address',
            value: AppConfig.supportAddress,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(value, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
