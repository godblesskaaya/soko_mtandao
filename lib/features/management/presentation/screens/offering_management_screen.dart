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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(offeringsProvider(hotelId).future);
        },
        child: offeringsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(
                child: Column(
                  children: [
                    Text("Error: $err"),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(offeringsProvider(hotelId)),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (offerings) {
            if (offerings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  const Center(child: Text("No offerings yet.")),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: offerings.length,
              itemBuilder: (_, i) {
                final off = offerings[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(off.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(off.description),
                        Text("TZS ${off.basePrice}/night"),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.pushNamed(
                        "editOffering",
                        pathParameters: {
                          "offeringId": ?off.id,
                          "hotelId": hotelId,
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(
          "addOfferings",
          pathParameters: {"hotelId": hotelId},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
