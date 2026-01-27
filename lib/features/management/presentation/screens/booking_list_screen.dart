import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soko_mtandao/features/management/presentation/riverpod/manager_booking_providers.dart';

class BookingListScreen extends ConsumerWidget {
  final String hotelId;
  const BookingListScreen({super.key, required this.hotelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingDataAsync =
        ref.watch(bookingListCombinedProvider(hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text("Bookings")),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(
            bookingListCombinedProvider(hotelId).future,
          );
        },
        child: bookingDataAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),

          error: (err, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text("Error: $err")),
              const SizedBox(height: 12),
              const Center(child: Text("Pull down to retry")),
            ],
          ),

          data: (bookingList) {
            if (bookingList.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No bookings yet.")),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: bookingList.length,
              itemBuilder: (context, i) {
                final data = bookingList[i];

                return Card(
                  child: ListTile(
                    title: Text(
                      data.detail.customerName ?? "Anonymous",
                    ),
                    subtitle: Text(
                      "Room: ${data.room.roomNumber} → "
                      "${data.booking.startDate?.toIso8601String().substring(0, 10)}   "
                      "${data.booking.endDate?.toIso8601String().substring(0, 10)}",
                    ),
                    trailing: Text(
                      data.detail.status ?? "unknown",
                    ),
                    onTap: () async {
                      await context.push(
                        "/manager/bookings/${data.detail.id}",
                      );

                      // Refresh when coming back
                      ref.invalidate(
                        bookingListCombinedProvider(hotelId),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
