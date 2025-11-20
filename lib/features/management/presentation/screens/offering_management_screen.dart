// features/manager/presentation/screens/offering_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_offering_providers.dart';

class OfferingListScreen extends ConsumerWidget {
  final String hotelId;
  const OfferingListScreen({super.key, required this.hotelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(offeringsProvider(hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text("Offerings")),
      body: offeringsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (offerings) {
          if (offerings.isEmpty) {
            return const Center(child: Text("No offerings yet."));
          }
          return ListView.builder(
            itemCount: offerings.length,
            itemBuilder: (_, i) {
              final off = offerings[i];
              return Card(
                child: ListTile(
                  title: Text(off.title),
                  subtitle: Text("From \$${off.basePrice}/night"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => Navigator.pushNamed(
                        context, "/manager/offerings/${off.id}/edit"),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed("addOfferings", pathParameters: {"hotelId": hotelId}),
        child: const Icon(Icons.add),
      ),
    );
  }
}
