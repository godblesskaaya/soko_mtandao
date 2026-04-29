import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soko_mtandao/core/constants/roles.dart';
import 'package:soko_mtandao/core/services/providers.dart';

class PersonaSwitcherButton extends ConsumerWidget {
  const PersonaSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider);
    final personas = authNotifier.availablePersonas;

    if (personas.length < 2) {
      return const SizedBox.shrink();
    }

    final current = authNotifier.role;

    return PopupMenuButton<UserRole>(
      tooltip: 'Switch persona',
      icon: Chip(
        label: Text(
          roleLabel(current),
          style: const TextStyle(fontSize: 12),
        ),
        avatar: const Icon(Icons.swap_horiz, size: 16),
      ),
      onSelected: (role) async {
        if (role == current) return;
        try {
          await ref.read(authNotifierProvider).setActivePersona(role);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to ${roleLabel(role)}')),
            );
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.toString())),
            );
          }
        }
      },
      itemBuilder: (_) => personas
          .map(
            (role) => PopupMenuItem<UserRole>(
              value: role,
              child: Row(
                children: [
                  Icon(
                    role == current ? Icons.check_circle : Icons.person_outline,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(roleLabel(role)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
