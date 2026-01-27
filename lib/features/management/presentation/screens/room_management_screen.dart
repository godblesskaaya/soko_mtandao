// features/manager/presentation/screens/offering_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';

class RoomListScreen extends ConsumerWidget {
  final String hotelId;
  const RoomListScreen({super.key, required this.hotelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider(hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text("Rooms")),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(roomsProvider(hotelId).future);
        },
        child: roomsAsync.when(
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
                      onPressed: () => ref.invalidate(roomsProvider(hotelId)),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (rooms) {
            if (rooms.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No rooms yet.")),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rooms.length,
              itemBuilder: (_, i) {
                final room = rooms[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Room Number: ${room.roomNumber}'),
                    subtitle: Text("Capacity: ${room.capacity} people"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.pushNamed(
                        "editRoom",
                        pathParameters: {"roomId": room.id, "hotelId": hotelId},
                      ),
                    ),
                    onTap: () => context.pushNamed(
                      "roomDetails",
                      pathParameters: {"roomId": room.id},
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
          "addRooms",
          pathParameters: {"hotelId": hotelId},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

