import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/core/errors/error_mapper.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_rom_details_provider.dart';
import '../widgets/room_header_card.dart';
import '../widgets/room_action_buttons.dart';

class ManagerRoomDetailsPage extends ConsumerWidget {
  final String roomId;

  const ManagerRoomDetailsPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoomDetails = ref.watch(managerRoomDetailsProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Room Details"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(managerRoomDetailsProvider(roomId));
          try {
            await ref
                .read(managerRoomDetailsProvider(roomId).future)
                .timeout(const Duration(seconds: 8));
          } catch (_) {}
        },
        child: asyncRoomDetails.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(
                child: Column(
                  children: [
                    Text(userMessageForError(error)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(managerRoomDetailsProvider(roomId));
                      },
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
            ],
          ),
          data: (details) {
            final room = details.room;
            final offering = details.offering;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoomHeaderCard(room: room, offering: offering),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => context.pushNamed(
                      "roomBookings",
                      pathParameters: {"roomId": room.id},
                    ),
                    icon: const Icon(Icons.add_chart_outlined),
                    label: const Text("Room Booking Statistics"),
                  ),
                  const SizedBox(height: 20),
                  RoomActions(roomId: roomId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
