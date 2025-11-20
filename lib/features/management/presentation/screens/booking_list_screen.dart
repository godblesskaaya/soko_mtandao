// features/manager/presentation/screens/booking_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_booking.dart';
import 'package:soko_mtandao/features/management/domain/entities/manager_room.dart';
import 'package:soko_mtandao/features/management/domain/usecases/bookings/get_bookings.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_room_providers.dart';

class BookingListScreen extends ConsumerWidget {
  final String hotelId;
  const BookingListScreen({super.key, required this.hotelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
final bookingDataAsync = ref.watch(bookingListCombinedProvider(hotelId));

return Scaffold(
  backgroundColor: Colors.transparent,
  appBar: AppBar(title: const Text("Bookings")),
  body: bookingDataAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (err, _) => Center(child: Text("Error: $err")),
    data: (bookingList) {
      if (bookingList.isEmpty) {
        return const Center(child: Text("No bookings yet."));
      }

      return ListView.builder(
        itemCount: bookingList.length,
        itemBuilder: (context, i) {
          final data = bookingList[i];
          return Card(
            child: ListTile(
              title: Text(data.detail.customerName ?? "Anonymous"),
              subtitle: Text("Room: ${data.room.roomNumber} → ${data.booking.startDate?.toIso8601String().substring(0, 10)}   ${data.booking.endDate?.toIso8601String().substring(0, 10)}"),
              trailing: Text(data.detail.status ?? "unknown"),
              onTap: () => context.push("/manager/bookings/${data.detail.id}"),
            ),
          );
        },
      );
    },
  ),
);
  }
}

extension on AsyncValue<ManagerRoom> {
   get future => null;
}
