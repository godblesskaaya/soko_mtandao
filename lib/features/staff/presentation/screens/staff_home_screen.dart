import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/widgets/persona_switcher_button.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Workspace'),
        actions: const [PersonaSwitcherButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Operations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Track bookings and manage room operations for your assigned hotel.',
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.book_online_outlined),
                title: const Text('Open Booking Lookup'),
                subtitle: const Text('Find and verify customer bookings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.goNamed('bookings'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile & Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.goNamed('profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
