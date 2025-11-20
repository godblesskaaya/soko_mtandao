// features/manager/presentation/screens/hotel_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';

class ManagerHotelListScreen extends ConsumerWidget {
  final String managerUserId;
  const ManagerHotelListScreen({required this.managerUserId, super.key, });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelsAsync = ref.watch(managerHotelsProvider(managerUserId)); // pass real managerId

    return Scaffold(
      appBar: AppBar(title: const Text("My Hotels")),
      body: hotelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stackTrace) {
           print(stackTrace);
          return Center(child: Text("Error: $err"));
        },
        data: (hotels) {
          if (hotels.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("No hotels found."),
                  ElevatedButton(
                    onPressed: () => context.pushNamed("addHotel"),
                    child: const Text("Add Hotel"),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: hotels.length,
            itemBuilder: (_, index) {
              final h = hotels[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: h.images.isNotEmpty
                      ? Image.network(h.images.first, width: 60, fit: BoxFit.cover)
                      : const Icon(Icons.hotel, size: 40),
                  title: Text(h.name),
                  subtitle: Text(h.address ?? ""),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.pushNamed("hotelEdit", pathParameters: {"hotelId": h.id}),
                  ),
                  onTap: () => context.pushNamed("hotelPage", pathParameters: {"hotelId": h.id}),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed("addHotel"),
        child: const Icon(Icons.add),
      ),
    );
  }
}
