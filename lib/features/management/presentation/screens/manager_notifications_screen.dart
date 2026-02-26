import 'package:flutter/material.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class ManagerNotificationsScreen extends StatelessWidget {
  const ManagerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AppStateView.empty(
        title: 'No new notifications',
        subtitle:
            'Updates about bookings, payouts, and alerts will appear here.',
      ),
    );
  }
}
