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
      appBar: AppBar(title: const Text("rooms")),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(child: Text("No rooms yet."));
          }
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (_, i) {
              final room = rooms[i];
              return Card(
                child: ListTile(
                  title: Text('Room Number: ${room.roomNumber}'),
                  subtitle: Text("From ${room.capacity} people"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.pushNamed(
                        "roomDetails", pathParameters: {"roomId": room.id}),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed("addRooms", pathParameters: {"hotelId": hotelId}),
        child: const Icon(Icons.add),
      ),
    );
  }
}
