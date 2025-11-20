import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/hotel_detail/domain/entities/room_status.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_rom_details_provider.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_actions_provider.dart';
import '../widgets/room_header_card.dart';
import '../widgets/room_action_buttons.dart';

class ManagerRoomDetailsPage extends ConsumerWidget {
  final String roomId;

  const ManagerRoomDetailsPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoomDetails = ref.watch(managerRoomDetailsProvider(roomId));

    return asyncRoomDetails.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text('Error loading room details: $error'),
        ),
      ),
      data: (details) {
        final room = details.room;
        final offering = details.offering;

        return Scaffold(
          appBar: AppBar(
            title: Text("Room ${room.roomNumber}"),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Navigate to edit page
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoomHeaderCard(room: room, offering: offering),
                const SizedBox(height: 20),
                // RoomOfferingSection(offering: offering),
                // const SizedBox(height: 20),
                IconButton(
                  icon: const Icon(Icons.add_chart_outlined),
                  onPressed: () => context.pushNamed(
                      "roomBookings", pathParameters: {"roomId": room.id}),
                ),

                const SizedBox(height: 20),
                RoomActions(
                  roomId: roomId,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
