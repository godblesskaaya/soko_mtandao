import 'package:flutter/material.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/core/constants/app_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const _lastUpdated = 'April 25, 2026';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Soko Mtandao Terms & Conditions',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: $_lastUpdated',
            style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Text(
            'These terms govern access to the Soko Mtandao app and related services for guests, customers, hotel staff, hotel administrators, and system administrators. By creating an account, browsing listings, managing a hotel, or completing a booking or payment, you agree to these terms.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          const _TermsSection(
            title: '1. Platform role',
            body:
                'Soko Mtandao operates as a hospitality marketplace and hotel operations platform. The app helps users discover hotels, make bookings, manage hotel inventory, process checkout flows, and support hotel administration. Unless clearly stated otherwise, hotel inventory, room availability, amenities, pricing, taxes, and stay rules are provided by the relevant hotel or operator.',
          ),
          const _TermsSection(
            title: '2. Eligibility and accounts',
            body:
                'You must provide accurate and complete information when signing up or using the app. You are responsible for maintaining the security of your login credentials and for all activity under your account. Accounts may be limited, suspended, or removed if we detect misuse, fraud, policy violations, inaccurate compliance information, or activity that creates risk for guests, hotels, payment partners, or the platform.',
          ),
          const _TermsSection(
            title: '3. Bookings and hotel information',
            body:
                'When a customer submits booking details, the booking request, pricing summary, room selection, dates, and occupancy information must be reviewed before payment. Booking confirmation depends on successful processing, current availability, and backend validation. Hotels are responsible for keeping room details, stay rules, check-in requirements, amenities, and operational contact information accurate inside the platform.',
          ),
          const _TermsSection(
            title: '4. Payments and refunds',
            body:
                'The current application state includes hosted and native payment flows connected to AzamPay, with booking and payment records coordinated through Supabase backend services. Payment completion is not final until the platform receives successful confirmation from the payment flow and updates the booking status. Refunds, reversals, failed payments, charge disputes, payout delays, gateway outages, and settlement timing may depend on hotel policies, payment partner rules, banking networks, and applicable law.',
          ),
          const _TermsSection(
            title: '5. Hotel manager and staff responsibilities',
            body:
                'Hotel admins and staff must only access hotels, bookings, payments, rooms, offerings, customer details, and operational tools they are authorized to manage. KYC, legal identity, payout, and team-association data must be truthful and kept current. You may not upload unlawful content, manipulate availability or pricing in bad faith, misuse customer information, or attempt to bypass platform controls, audits, or permissions.',
          ),
          const _TermsSection(
            title: '6. Third-party services',
            body:
                'The app currently depends on third-party infrastructure and services, including Supabase for authentication, backend data, storage, and edge functions; AzamPay for payment initiation and callbacks; and Mapbox for map and location experiences. These providers may affect uptime, performance, routing, payment status updates, location display, and related service behavior. Your use of features powered by those services may also be subject to the provider terms and policies that apply to them.',
          ),
          const _TermsSection(
            title: '7. Availability and service changes',
            body:
                'We may update, pause, restrict, or remove parts of the app, including booking flows, hotel management tools, onboarding, payments, notifications, or integrations, where needed for maintenance, legal compliance, security, or product changes. We do not guarantee uninterrupted availability, real-time synchronization, or error-free operation across all devices, browsers, or network conditions.',
          ),
          const _TermsSection(
            title: '8. Acceptable use',
            body:
                'You must not use the app to commit fraud, scrape protected data, interfere with other users, upload malicious content, attempt unauthorized access, reverse engineer protected systems, submit fake bookings, abuse refund or payout workflows, or violate hotel, payment, privacy, or consumer protection rules. We may investigate misuse and cooperate with hotels, payment providers, regulators, or law enforcement when required.',
          ),
          const _TermsSection(
            title: '9. Data, privacy, and communications',
            body:
                'Your use of the platform is also subject to the Privacy Policy. By using the app, you consent to operational communications needed for account access, onboarding, booking support, payment follow-up, and security review. Some account, booking, KYC, payment, and audit data may be retained where required for fraud prevention, legal obligations, dispute handling, financial reporting, or platform security.',
          ),
          const _TermsSection(
            title: '10. Liability and disputes',
            body:
                'To the maximum extent permitted by law, Soko Mtandao is not responsible for indirect, incidental, special, or consequential losses arising from hotel conduct, inaccurate listing content supplied by operators, third-party outages, failed networks, delayed payment confirmations, or user misuse of the platform. Nothing in these terms removes rights that cannot lawfully be excluded under applicable consumer or data protection law.',
          ),
          const _TermsSection(
            title: '11. Changes to these terms',
            body:
                'We may revise these terms from time to time. Updated terms take effect when published in the app or otherwise communicated. Continued use of the service after an update means you accept the revised terms.',
          ),
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Questions about these terms?',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Email: ${AppConfig.supportEmail}\nPhone: ${AppConfig.supportPhone}\nAddress: ${AppConfig.supportAddress}\n\nFor production use, these terms should also be reviewed by local counsel before release.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
