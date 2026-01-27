// features/manager/presentation/screens/hotel_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_hotel_providers.dart';

class ManagerHotelListScreen extends ConsumerWidget {
  final String managerUserId;
  const ManagerHotelListScreen({
    super.key,
    required this.managerUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelsAsync =
        ref.watch(managerHotelsProvider(managerUserId));

    return Scaffold(
      appBar: AppBar(title: const Text("My Hotels")),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(
            managerHotelsProvider(managerUserId).future,
          );
        },
        child: hotelsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),

          error: (err, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text("Error: $err")),
              const SizedBox(height: 8),
              const Center(child: Text("Pull down to retry")),
            ],
          ),

          data: (hotels) {
            if (hotels.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  const Center(child: Text("No hotels found.")),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.pushNamed("addHotel");
                        ref.invalidate(
                          managerHotelsProvider(managerUserId),
                        );
                      },
                      child: const Text("Add Hotel"),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: hotels.length,
              itemBuilder: (_, index) {
                final h = hotels[index];

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: h.images.isNotEmpty
                        ? Image.network(
                            h.images.first,
                            width: 60,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.hotel, size: 40),
                    title: Text(h.name),
                    subtitle: Text(h.address ?? ""),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        await context.pushNamed(
                          "hotelEdit",
                          pathParameters: {"hotelId": h.id},
                        );
                        ref.invalidate(
                          managerHotelsProvider(managerUserId),
                        );
                      },
                    ),
                    onTap: () async {
                      await context.pushNamed(
                        "hotelPage",
                        pathParameters: {"hotelId": h.id},
                      );
                      ref.invalidate(
                        managerHotelsProvider(managerUserId),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.pushNamed("addHotel");
          ref.invalidate(
            managerHotelsProvider(managerUserId),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
