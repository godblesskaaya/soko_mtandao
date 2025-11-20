import 'package:flutter/material.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_offering.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';

class RoomHeaderCard extends StatelessWidget {
  final ManagerRoom room;
  final ManagerOffering? offering;

  const RoomHeaderCard({
    super.key,
    required this.room,
    this.offering,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(room.roomNumber),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offering?.title ?? "Unknown Offering",
                      style: Theme.of(context).textTheme.titleMedium),
                  Text("Capacity: ${room.capacity} guests"),
                  Text(
                    room.isActive ? "Status: Available" : "Out of service",
                    style: TextStyle(
                      color: room.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
