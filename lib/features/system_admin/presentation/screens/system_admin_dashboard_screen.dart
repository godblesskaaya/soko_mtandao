import 'package:flutter/material.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class SystemAdminDashboardScreen extends StatelessWidget {
  const SystemAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Admin')),
      body: AppStateView.empty(
        title: 'System dashboard is under rollout',
        subtitle:
            'Core controls are being finalized. Full governance tools will appear here.',
      ),
    );
  }
}
