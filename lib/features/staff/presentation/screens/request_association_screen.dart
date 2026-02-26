import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/config/app_config.dart';
import 'package:soko_mtandao/widgets/app_state_view.dart';

class RequestAssociationScreen extends StatelessWidget {
  const RequestAssociationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotel Association')),
      body: AppStateView.empty(
        title: 'No hotel assigned yet',
        subtitle:
            'Ask your manager to add you to a property. For urgent support, contact ${AppConfig.supportEmail}.',
        actionLabel: 'Back to Profile',
        onAction: () => context.goNamed('profile'),
      ),
    );
  }
}
